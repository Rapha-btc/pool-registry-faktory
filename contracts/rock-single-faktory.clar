;; Title: rock-single-faktory
;; Summary: Single-sided sBTC offering for the ROCK/sBTC gated pool
;;   (.rock-faktory-pool-3). The depositor seeds ROCK once; users bring only
;;   sBTC during the entry window and the contract pairs it at the pool ratio.
;;   Because the pool's swaps stay gated until after the window, every deposit
;;   pairs at the seeded price - the ratio cannot be manipulated by selling
;;   into the pool.
;;
;; Pattern: mia-single-faktory-v2 (Clarity 6 body against a gated pool) with
;; the pepe-single-faktory features folded back in:
;;   - dynamic depositor: whoever calls initialize-pool first (Highroller)
;;   - ENTRY_PERIOD u3024 (~3 weeks): deposits close, then the depositor can
;;     sweep unused ROCK via withdraw-remaining-token
;;   - LOCK_PERIOD u12960 (~90 days): LP locked; on withdraw the LP is fully
;;     removed and BOTH sides split USER_BPS/100 user, rest to the depositor
;;   - withdraw-lp-tokens-depositor: depositor can push a user's withdrawal
;;     out after unlock (keeps the pool from carrying zombie LP forever)

(define-constant POOL .rock-faktory-pool-3)
(define-constant SBTC 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token)
(define-constant ROCK 'SP4M2C88EE8RQZPYTC4PZ88CE16YGP825EYF6KBQ.stacks-rock)

(define-constant ERR_UNAUTHORIZED (err u403))
(define-constant ERR_NOT_INITIALIZED (err u404))
(define-constant ERR_ALREADY_INITIALIZED (err u405))
(define-constant ERR_INSUFFICIENT_AMOUNT (err u406))
(define-constant ERR_STILL_LOCKED (err u407))
(define-constant ERR_NO_DEPOSIT (err u408))
(define-constant ERR_TOO_LATE (err u409))
(define-constant ERR_CALC_AMOUNTS (err u410))

(define-constant MIN_LP_AMOUNT u20)

(define-constant LOCK_PERIOD u12960)  ;; ~90 days of burn blocks
(define-constant ENTRY_PERIOD u3024)  ;; ~3 weeks of burn blocks

(define-constant USER_BPS u60)        ;; user keeps 60% of both sides

(define-data-var depositor (optional principal) none)
(define-data-var creation-block uint u0)
(define-data-var initial-token-amount uint u0)
(define-data-var token-used-for-lp uint u0)
(define-data-var total-lp-tokens uint u0)

(define-map user-lp-tokens principal uint)

(define-public (initialize-pool (token-amount uint))
  (begin
    (asserts! (is-none (var-get depositor)) ERR_ALREADY_INITIALIZED)
    (asserts! (> token-amount u0) ERR_INSUFFICIENT_AMOUNT)

    (try! (contract-call? ROCK transfer token-amount tx-sender current-contract none))

    (var-set depositor (some tx-sender))
    (var-set creation-block burn-block-height)
    (var-set initial-token-amount token-amount)

    (print {
      type: "pool-initialized",
      depositor: tx-sender,
      token-amount: token-amount,
      ft: ROCK,
      entry-ends: (+ burn-block-height ENTRY_PERIOD),
      unlock-block: (+ burn-block-height LOCK_PERIOD)
    })

    (ok true)
  )
)

(define-public (deposit-sbtc-for-lp (lp-amount uint))
    (let (
          (amounts (unwrap! (calculate-amounts-for-lp lp-amount) ERR_CALC_AMOUNTS))
          (sbtc-needed (get sbtc-needed amounts))
          (token-needed (get token-needed amounts))
          (deposit (try! (contract-call? SBTC transfer sbtc-needed tx-sender current-contract none)))
          (lp-result (try! (as-contract? ((with-ft SBTC "sbtc-token" sbtc-needed)
                                          (with-ft ROCK "rock" token-needed))
                             (try! (contract-call? POOL add-liquidity lp-amount)))))
          (lp-tokens-received (get dk lp-result))
          (current-lp (default-to u0 (map-get? user-lp-tokens tx-sender))))

    (asserts! (is-some (var-get depositor)) ERR_NOT_INITIALIZED)
    (asserts! (< burn-block-height (+ (var-get creation-block) ENTRY_PERIOD)) ERR_TOO_LATE)
    (asserts! (not (is-eq (some tx-sender) (var-get depositor))) ERR_UNAUTHORIZED)
    (asserts! (>= lp-amount MIN_LP_AMOUNT) ERR_INSUFFICIENT_AMOUNT)

      (map-set user-lp-tokens tx-sender (+ current-lp lp-tokens-received))
      (var-set total-lp-tokens (+ (var-get total-lp-tokens) lp-tokens-received))
      (var-set token-used-for-lp (+ (var-get token-used-for-lp) token-needed))

      (print {
        type: "community-lp-deposit",
        user: tx-sender,
        sbtc-in: sbtc-needed,
        token-used: token-needed,
        lp-tokens: lp-tokens-received,
        unlock-block: (+ (var-get creation-block) LOCK_PERIOD),
        ft: ROCK
      })

      (ok lp-tokens-received)
    )
  )

;; Shared exit: remove `user-lp` LP entirely, both sides split
;; USER_BPS/(100-USER_BPS) between the user and the depositor (pepe pattern).
(define-private (do-withdraw (user principal))
  (let ((unlock-block (+ (var-get creation-block) LOCK_PERIOD))
        (user-lp (default-to u0 (map-get? user-lp-tokens user)))
        (depositor-principal (unwrap! (var-get depositor) ERR_NOT_INITIALIZED)))
    (asserts! (>= burn-block-height unlock-block) ERR_STILL_LOCKED)
    (asserts! (> user-lp u0) ERR_NO_DEPOSIT)

    (let ((remove-result (try! (as-contract? ((with-ft POOL "sBTC-rock" user-lp))
                                 (try! (contract-call? POOL remove-liquidity user-lp)))))
          (sbtc-received (get dx remove-result))
          (token-received (get dy remove-result))
          (user-sbtc-share (/ (* sbtc-received USER_BPS) u100))
          (depositor-sbtc-share (- sbtc-received user-sbtc-share))
          (user-token-share (/ (* token-received USER_BPS) u100))
          (depositor-token-share (- token-received user-token-share)))

        (try! (as-contract? ((with-ft SBTC "sbtc-token" sbtc-received))
               (begin
                 (try! (contract-call? SBTC transfer user-sbtc-share current-contract user none))
                 (try! (contract-call? SBTC transfer depositor-sbtc-share current-contract depositor-principal none)))))
        (try! (as-contract? ((with-ft ROCK "rock" token-received))
               (begin
                 (try! (contract-call? ROCK transfer user-token-share current-contract user none))
                 (try! (contract-call? ROCK transfer depositor-token-share current-contract depositor-principal none)))))

        (map-delete user-lp-tokens user)
        (var-set total-lp-tokens (- (var-get total-lp-tokens) user-lp))

        (print {
          type: "lp-withdrawal",
          user: user,
          withdrawn-by: tx-sender,
          lp-tokens: user-lp,
          user-sbtc: user-sbtc-share,
          user-token: user-token-share,
          depositor-sbtc: depositor-sbtc-share,
          depositor-token: depositor-token-share,
          ft: ROCK
        })

        (ok user-lp)
      )
    )
  )

(define-public (withdraw-lp-tokens)
  (do-withdraw tx-sender)
)

(define-public (withdraw-lp-tokens-depositor (user principal))
  (begin
    (asserts! (is-eq (some tx-sender) (var-get depositor)) ERR_UNAUTHORIZED)
    (do-withdraw user)
  )
)

;; After the entry window the depositor takes back whatever ROCK was never
;; paired. Users who deposited are unaffected: their LP is already in the pool.
(define-public (withdraw-remaining-token)
  (let ((entry-end-block (+ (var-get creation-block) ENTRY_PERIOD))
        (depositor-principal (unwrap! (var-get depositor) ERR_NOT_INITIALIZED)))
    (asserts! (>= burn-block-height entry-end-block) ERR_STILL_LOCKED)
    (asserts! (is-eq tx-sender depositor-principal) ERR_UNAUTHORIZED)

    (let ((remaining-token (- (var-get initial-token-amount) (var-get token-used-for-lp))))

      (and (> remaining-token u0)
           (try! (as-contract? ((with-ft ROCK "rock" remaining-token))
                  (try! (contract-call? ROCK transfer remaining-token current-contract depositor-principal none)))))

      (print {
        type: "token-withdrawal",
        amount: remaining-token,
        ft: ROCK
      })

      (ok remaining-token)
    )
  )
)

(define-read-only (get-pool-info)
  {
    depositor: (var-get depositor),
    creation-block: (var-get creation-block),
    started: (> (var-get creation-block) u0),
    entry-ends: (+ (var-get creation-block) ENTRY_PERIOD),
    unlock-block: (+ (var-get creation-block) LOCK_PERIOD),
    is-unlocked: (and (> (var-get creation-block) u0)
                      (>= burn-block-height (+ (var-get creation-block) LOCK_PERIOD))),
    initial-token: (var-get initial-token-amount),
    token-used: (var-get token-used-for-lp),
    token-available: (- (var-get initial-token-amount) (var-get token-used-for-lp)),
    total-lp-tokens: (var-get total-lp-tokens),
    user-bps: USER_BPS
  }
)

(define-read-only (get-user-lp-tokens (user principal))
  (default-to u0 (map-get? user-lp-tokens user))
)

(define-read-only (get-quote-for-lp (lp-amount uint))
  (contract-call? .rock-faktory-pool-3 quote lp-amount (some 0x02)))

(define-read-only (calculate-amounts-for-lp (lp-amount uint))
  (begin
        (asserts! (> lp-amount u0) ERR_INSUFFICIENT_AMOUNT)
        (match (get-quote-for-lp lp-amount)
          liquidity-quote (ok {
            sbtc-needed: (get dx liquidity-quote),
            token-needed: (get dy liquidity-quote)
          })
          error-value (err error-value))))

(define-read-only (get-config)
    {
        ft: ROCK,
        pool: POOL,
        denomination: SBTC,
        depositor: (var-get depositor),
    }
)
