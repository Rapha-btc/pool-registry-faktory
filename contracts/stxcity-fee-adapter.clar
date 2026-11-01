;; stxcity-fee-adapter
;;
;; fak.fun front door for STX.CITY tokens (AI DAO launches): takes a fee in STX
;; for fak.fun, then trades for the user in the same tx.
;;
;;   buy-curve  STX -> token on a STX.CITY bonding-curve dex (still tradable)
;;   buy-pool   STX -> token on the Bitflow XYK pool a curve graduated into
;;   sell-pool  token -> STX on that Bitflow pool (fee taken from the STX out)
;;
;; No curve sell: STX.CITY `sell` asserts contract-caller == tx-sender, so it
;; can only be called directly by the user (no fee possible there).
;;
;; Nothing runs as-contract: the dex / Bitflow core see tx-sender = the user,
;; so STX and tokens move straight between the user and the venue, and this
;; contract never holds funds. The user's post-conditions bound every transfer.
;; Adds the slippage guard the curve itself lacks (min-tokens-out).

(use-trait sip-010-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)
(use-trait bf-sip-010-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.sip-010-trait-ft-standard-v-1-1.sip-010-trait)
(use-trait xyk-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)

;; the STX.CITY bonding-curve dex `buy` (v2.0 template)
(define-trait stxcity-dex-trait
  ((buy (<sip-010-trait> uint) (response uint uint))))

(define-constant BPS u10000)
(define-constant MAX_FEE_BPS u300) ;; 3% hard cap

(define-constant ERR_NOT_OWNER (err u5001))
(define-constant ERR_NOT_APPROVED (err u5002))
(define-constant ERR_ZERO_AMOUNT (err u5003))
(define-constant ERR_SLIPPAGE (err u5004))
(define-constant ERR_FEE_TOO_HIGH (err u5005))

(define-data-var owner principal tx-sender)
(define-data-var pending-owner (optional principal) none)
(define-data-var fee-recipient principal tx-sender)
(define-data-var fee-bps uint u100) ;; 1%

;; curve dexes and Bitflow pools fak.fun routes to
(define-map approved principal bool)

(define-read-only (get-fee-bps) (var-get fee-bps))
(define-read-only (get-fee-recipient) (var-get fee-recipient))
(define-read-only (get-owner) (var-get owner))
(define-read-only (is-approved (venue principal)) (default-to false (map-get? approved venue)))
(define-read-only (fee-of (amount uint)) (/ (* amount (var-get fee-bps)) BPS))

(define-private (pay-fee (fee uint))
  (if (or (is-eq fee u0) (is-eq tx-sender (var-get fee-recipient)))
    (ok true)
    (stx-transfer? fee tx-sender (var-get fee-recipient))))

;; ---- trades -----------------------------------------------------------------

(define-public (buy-curve (dex <stxcity-dex-trait>) (token <sip-010-trait>) (stx-amount uint) (min-tokens-out uint))
  (let (
      (fee (fee-of stx-amount))
      (net (- stx-amount fee))
    )
    (asserts! (is-approved (contract-of dex)) ERR_NOT_APPROVED)
    (asserts! (> net u0) ERR_ZERO_AMOUNT)
    (try! (pay-fee fee))
    (let ((out (try! (contract-call? dex buy token net))))
      (asserts! (>= out min-tokens-out) ERR_SLIPPAGE)
      (print { event: "stxcity-buy-curve", user: tx-sender, dex: (contract-of dex), token: (contract-of token),
               stx-in: stx-amount, fee: fee, tokens-out: out })
      (ok out))))

(define-public (buy-pool (pool <xyk-pool-trait>) (stx-token <bf-sip-010-trait>) (token <bf-sip-010-trait>)
                         (stx-amount uint) (min-tokens-out uint))
  (let (
      (fee (fee-of stx-amount))
      (net (- stx-amount fee))
    )
    (asserts! (is-approved (contract-of pool)) ERR_NOT_APPROVED)
    (asserts! (> net u0) ERR_ZERO_AMOUNT)
    (try! (pay-fee fee))
    ;; STX is x in the xyk-pool-stx-<token> pools; core checks both tokens
    (let ((out (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2
                       swap-x-for-y pool stx-token token net min-tokens-out))))
      (print { event: "stxcity-buy-pool", user: tx-sender, pool: (contract-of pool), token: (contract-of token),
               stx-in: stx-amount, fee: fee, tokens-out: out })
      (ok out))))

(define-public (sell-pool (pool <xyk-pool-trait>) (stx-token <bf-sip-010-trait>) (token <bf-sip-010-trait>)
                          (tokens-in uint) (min-stx-out uint))
  (begin
    (asserts! (is-approved (contract-of pool)) ERR_NOT_APPROVED)
    (asserts! (> tokens-in u0) ERR_ZERO_AMOUNT)
    (let (
        ;; core needs min-dx > 0: the gross that leaves min-stx-out after our fee
        (min-gross (/ (* min-stx-out BPS) (- BPS (var-get fee-bps))))
        (gross (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2
                       swap-y-for-x pool stx-token token tokens-in (if (> min-gross u0) min-gross u1))))
        (fee (fee-of gross))
        (net (- gross fee))
      )
      ;; min on what the user keeps, after our fee
      (asserts! (>= net min-stx-out) ERR_SLIPPAGE)
      (try! (pay-fee fee))
      (print { event: "stxcity-sell-pool", user: tx-sender, pool: (contract-of pool), token: (contract-of token),
               tokens-in: tokens-in, stx-out: gross, fee: fee })
      (ok net))))

;; ---- owner ------------------------------------------------------------------

(define-private (set-one (venue principal) (ok-flag bool))
  (begin (map-set approved venue ok-flag) ok-flag))

(define-public (set-approved (venues (list 100 principal)) (flag bool))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_NOT_OWNER)
    (map set-one venues (list flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag flag))
    (print { event: "stxcity-adapter-approved", venues: venues, approved: flag })
    (ok true)))

(define-public (set-fee-bps (bps uint))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_NOT_OWNER)
    (asserts! (<= bps MAX_FEE_BPS) ERR_FEE_TOO_HIGH)
    (var-set fee-bps bps)
    (print { event: "stxcity-adapter-fee-bps", bps: bps })
    (ok true)))

(define-public (set-fee-recipient (who principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_NOT_OWNER)
    (var-set fee-recipient who)
    (print { event: "stxcity-adapter-fee-recipient", recipient: who })
    (ok true)))

(define-public (propose-owner (who principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_NOT_OWNER)
    (var-set pending-owner (some who))
    (print { event: "stxcity-adapter-owner-proposed", owner: who })
    (ok true)))

(define-public (accept-owner)
  (begin
    (asserts! (is-eq (some tx-sender) (var-get pending-owner)) ERR_NOT_OWNER)
    (var-set owner tx-sender)
    (var-set pending-owner none)
    (print { event: "stxcity-adapter-owner-accepted", owner: tx-sender })
    (ok true)))
