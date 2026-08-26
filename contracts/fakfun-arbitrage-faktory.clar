;; SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-arbitrage-faktory (DRAFT - not deployed)
;;
;; Atomic triangular arb for FAKFUN, modeled on flatearth-arbitrage-faktory-v3.
;; FAKFUN has exactly two token venues:
;;   - Charisma sBTC pool SP2ZNGJ85...sbtc-fakfun-amm-lp-v1, called through
;;     fakfun-core-v2 execute (registered there; transfers net dy exactly, so
;;     no post-execute fee haircut).
;;   - bitflow xyk-pool-fakfun-stx-v-1-1 (x = FAKFUN, y = STX).
;; The sBTC<->STX hop bridges via bitflow sbtc-stx or Velar univ2 - four
;; paths total. Every path is profit-or-revert: output must exceed input or
;; the whole tx aborts, and profit lands with the DEPLOYER.

(define-constant ERR-SLIPPAGE (err u1000))
(define-constant ERR-NO-PROFIT (err u1001))
(define-constant ERR-NOT-AUTHORIZED (err u1002))

(define-constant DEPLOYER tx-sender)

(define-constant TOKEN 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-faktory)
(define-constant SBTC 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token)
(define-constant TOKEN-ASSET "FAKFUN")
(define-constant SBTC-ASSET "sbtc-token")

;; --- FAKFUN -> sBTC (Charisma) -> STX -> FAKFUN (bitflow token pool) ---

(define-public (arb-fak-bit-bit
    (token-in uint)
    (min-token-out uint)
  )
  (begin
    (try! (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-faktory
      transfer token-in tx-sender current-contract none
    ))
    (let (
        (sbtc-out (try! (as-contract? ((with-ft TOKEN TOKEN-ASSET token-in))
          (try! (swap-token-to-sbtc token-in))
        )))
        (stx-out (try! (as-contract? ((with-ft SBTC SBTC-ASSET sbtc-out))
          (try! (swap-sbtc-to-stx sbtc-out))
        )))
        (token-out (try! (as-contract? ((with-stx stx-out))
          (try! (swap-stx-to-token-bitflow stx-out))
        )))
      )
      (asserts! (>= token-out min-token-out) ERR-SLIPPAGE)
      (asserts! (> token-out token-in) ERR-NO-PROFIT)
      (try! (as-contract? ((with-ft TOKEN TOKEN-ASSET token-out))
        (try! (contract-call? TOKEN transfer token-out current-contract DEPLOYER none))
      ))
      (ok {
        token-in: token-in,
        token-out: token-out,
      })
    )
  )
)

;; --- FAKFUN -> sBTC (Charisma) -> STX (Velar) -> FAKFUN (bitflow) ---

(define-public (arb-fak-vel-bit
    (token-in uint)
    (min-token-out uint)
  )
  (begin
    (try! (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-faktory
      transfer token-in tx-sender current-contract none
    ))
    (let (
        (sbtc-out (try! (as-contract? ((with-ft TOKEN TOKEN-ASSET token-in))
          (try! (swap-token-to-sbtc token-in))
        )))
        (stx-out (try! (as-contract? ((with-ft SBTC SBTC-ASSET sbtc-out))
          (try! (swap-sbtc-to-stx-velar sbtc-out))
        )))
        (token-out (try! (as-contract? ((with-stx stx-out))
          (try! (swap-stx-to-token-bitflow stx-out))
        )))
      )
      (asserts! (>= token-out min-token-out) ERR-SLIPPAGE)
      (asserts! (> token-out token-in) ERR-NO-PROFIT)
      (try! (as-contract? ((with-ft TOKEN TOKEN-ASSET token-out))
        (try! (contract-call? TOKEN transfer token-out current-contract DEPLOYER none))
      ))
      (ok {
        token-in: token-in,
        token-out: token-out,
      })
    )
  )
)

;; --- FAKFUN -> STX (bitflow token pool) -> sBTC -> FAKFUN (Charisma) ---

(define-public (arb-bit-bit-fak
    (token-in uint)
    (min-token-out uint)
  )
  (begin
    (try! (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-faktory
      transfer token-in tx-sender current-contract none
    ))
    (let (
        (stx-out (try! (as-contract? ((with-ft TOKEN TOKEN-ASSET token-in))
          (try! (swap-token-to-stx-bitflow token-in))
        )))
        (sbtc-out (try! (as-contract? ((with-stx stx-out)) (try! (swap-stx-to-sbtc stx-out)))))
        (token-out (try! (as-contract? ((with-ft SBTC SBTC-ASSET sbtc-out))
          (try! (swap-sbtc-to-token sbtc-out))
        )))
      )
      (asserts! (>= token-out min-token-out) ERR-SLIPPAGE)
      (asserts! (> token-out token-in) ERR-NO-PROFIT)
      (try! (as-contract? ((with-ft TOKEN TOKEN-ASSET token-out))
        (try! (contract-call? TOKEN transfer token-out current-contract DEPLOYER none))
      ))
      (ok {
        token-in: token-in,
        token-out: token-out,
      })
    )
  )
)

;; --- FAKFUN -> STX (bitflow) -> sBTC (Velar) -> FAKFUN (Charisma) ---

(define-public (arb-bit-vel-fak
    (token-in uint)
    (min-token-out uint)
  )
  (begin
    (try! (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-faktory
      transfer token-in tx-sender current-contract none
    ))
    (let (
        (stx-out (try! (as-contract? ((with-ft TOKEN TOKEN-ASSET token-in))
          (try! (swap-token-to-stx-bitflow token-in))
        )))
        (sbtc-out (try! (as-contract? ((with-stx stx-out))
          (try! (swap-stx-to-sbtc-velar stx-out))
        )))
        (token-out (try! (as-contract? ((with-ft SBTC SBTC-ASSET sbtc-out))
          (try! (swap-sbtc-to-token sbtc-out))
        )))
      )
      (asserts! (>= token-out min-token-out) ERR-SLIPPAGE)
      (asserts! (> token-out token-in) ERR-NO-PROFIT)
      (try! (as-contract? ((with-ft TOKEN TOKEN-ASSET token-out))
        (try! (contract-call? TOKEN transfer token-out current-contract DEPLOYER none))
      ))
      (ok {
        token-in: token-in,
        token-out: token-out,
      })
    )
  )
)

;; --- Swap legs ---

(define-private (swap-token-to-sbtc (token-amount uint))
  (let ((result (try! (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-core-v2
      execute 'SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS.sbtc-fakfun-amm-lp-v1
      token-amount (some 0x01)
    ))))
    (ok (get dy result))
  )
)

(define-private (swap-sbtc-to-token (sbtc-amount uint))
  (let ((result (try! (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-core-v2
      execute 'SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS.sbtc-fakfun-amm-lp-v1
      sbtc-amount (some 0x00)
    ))))
    (ok (get dy result))
  )
)

(define-private (swap-sbtc-to-stx (sbtc-amount uint))
  (let ((dy (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2
      swap-x-for-y
      'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1
      'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2 sbtc-amount
      u1
    ))))
    (ok dy)
  )
)

(define-private (swap-stx-to-sbtc (stx-amount uint))
  (let ((dx (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2
      swap-y-for-x
      'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1
      'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2 stx-amount u1
    ))))
    (ok dx)
  )
)

;; bitflow token pool: x = FAKFUN, y = STX
(define-private (swap-stx-to-token-bitflow (stx-amount uint))
  (let ((dx (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2
      swap-y-for-x
      'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-fakfun-stx-v-1-1
      'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-faktory
      'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2 stx-amount u1
    ))))
    (ok dx)
  )
)

(define-private (swap-token-to-stx-bitflow (token-amount uint))
  (let ((dy (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2
      swap-x-for-y
      'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-fakfun-stx-v-1-1
      'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-faktory
      'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2 token-amount
      u1
    ))))
    (ok dy)
  )
)

(define-private (swap-sbtc-to-stx-velar (sbtc-amount uint))
  (let ((result (try! (contract-call?
      'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070 swap
      'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx
      'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-fees-v1_0_0-0070
      sbtc-amount u1
    ))))
    (ok (get amt-out result))
  )
)

(define-private (swap-stx-to-sbtc-velar (stx-amount uint))
  (let ((result (try! (contract-call?
      'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070 swap
      'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx
      'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-fees-v1_0_0-0070
      stx-amount u1
    ))))
    (ok (get amt-out result))
  )
)

;; --- Profitability checks (one per path) ---

(define-read-only (check-fak-bit-bit (token-in uint))
  (let (
      (sbtc-estimate (simulate-token-to-sbtc token-in))
      (stx-estimate (simulate-sbtc-to-stx sbtc-estimate))
      (token-estimate (simulate-stx-to-token-bitflow stx-estimate))
      (profit (if (> token-estimate token-in)
        (- token-estimate token-in)
        u0
      ))
    )
    (ok {
      token-in: token-in,
      sbtc-out: sbtc-estimate,
      stx-out: stx-estimate,
      token-out: token-estimate,
      profit: profit,
      profitable: (> token-estimate token-in),
    })
  )
)

(define-read-only (check-fak-vel-bit (token-in uint))
  (let (
      (sbtc-estimate (simulate-token-to-sbtc token-in))
      (stx-estimate (simulate-sbtc-to-stx-velar sbtc-estimate))
      (token-estimate (simulate-stx-to-token-bitflow stx-estimate))
      (profit (if (> token-estimate token-in)
        (- token-estimate token-in)
        u0
      ))
    )
    (ok {
      token-in: token-in,
      sbtc-out: sbtc-estimate,
      stx-out: stx-estimate,
      token-out: token-estimate,
      profit: profit,
      profitable: (> token-estimate token-in),
    })
  )
)

(define-read-only (check-bit-bit-fak (token-in uint))
  (let (
      (stx-estimate (simulate-token-to-stx-bitflow token-in))
      (sbtc-estimate (simulate-stx-to-sbtc stx-estimate))
      (token-estimate (simulate-sbtc-to-token sbtc-estimate))
      (profit (if (> token-estimate token-in)
        (- token-estimate token-in)
        u0
      ))
    )
    (ok {
      token-in: token-in,
      stx-out: stx-estimate,
      sbtc-out: sbtc-estimate,
      token-out: token-estimate,
      profit: profit,
      profitable: (> token-estimate token-in),
    })
  )
)

(define-read-only (check-bit-vel-fak (token-in uint))
  (let (
      (stx-estimate (simulate-token-to-stx-bitflow token-in))
      (sbtc-estimate (simulate-stx-to-sbtc-velar stx-estimate))
      (token-estimate (simulate-sbtc-to-token sbtc-estimate))
      (profit (if (> token-estimate token-in)
        (- token-estimate token-in)
        u0
      ))
    )
    (ok {
      token-in: token-in,
      stx-out: stx-estimate,
      sbtc-out: sbtc-estimate,
      token-out: token-estimate,
      profit: profit,
      profitable: (> token-estimate token-in),
    })
  )
)

;; --- Simulations ---

(define-read-only (simulate-token-to-sbtc (token-amount uint))
  (get dy
    (unwrap-panic (contract-call?
      'SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS.sbtc-fakfun-amm-lp-v1 quote
      token-amount (some 0x01)
    ))
  )
)

(define-read-only (simulate-sbtc-to-token (sbtc-amount uint))
  (get dy
    (unwrap-panic (contract-call?
      'SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS.sbtc-fakfun-amm-lp-v1 quote
      sbtc-amount (some 0x00)
    ))
  )
)

(define-read-only (simulate-sbtc-to-stx (sbtc-amount uint))
  (let (
      (pool (unwrap-panic (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1
        get-pool
      )))
      (x-balance (get x-balance pool))
      (y-balance (get y-balance pool))
      (protocol-fee (get x-protocol-fee pool))
      (provider-fee (get x-provider-fee pool))
      (BPS u10000)
      (x-amount-fees-protocol (/ (* sbtc-amount protocol-fee) BPS))
      (x-amount-fees-provider (/ (* sbtc-amount provider-fee) BPS))
      (x-amount-fees-total (+ x-amount-fees-protocol x-amount-fees-provider))
      (dx (- sbtc-amount x-amount-fees-total))
      (updated-x-balance (+ x-balance dx))
      (dy (/ (* y-balance dx) updated-x-balance))
    )
    dy
  )
)

(define-read-only (simulate-stx-to-sbtc (stx-amount uint))
  (let (
      (pool (unwrap-panic (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1
        get-pool
      )))
      (x-balance (get x-balance pool))
      (y-balance (get y-balance pool))
      (protocol-fee (get y-protocol-fee pool))
      (provider-fee (get y-provider-fee pool))
      (BPS u10000)
      (y-amount-fees-protocol (/ (* stx-amount protocol-fee) BPS))
      (y-amount-fees-provider (/ (* stx-amount provider-fee) BPS))
      (y-amount-fees-total (+ y-amount-fees-protocol y-amount-fees-provider))
      (dy (- stx-amount y-amount-fees-total))
      (updated-y-balance (+ y-balance dy))
      (dx (/ (* x-balance dy) updated-y-balance))
    )
    dx
  )
)

;; bitflow token pool: x = FAKFUN, y = STX
(define-read-only (simulate-stx-to-token-bitflow (stx-amount uint))
  (let (
      (pool (unwrap-panic (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-fakfun-stx-v-1-1
        get-pool
      )))
      (x-balance (get x-balance pool))
      (y-balance (get y-balance pool))
      (protocol-fee (get y-protocol-fee pool))
      (provider-fee (get y-provider-fee pool))
      (BPS u10000)
      (y-amount-fees-protocol (/ (* stx-amount protocol-fee) BPS))
      (y-amount-fees-provider (/ (* stx-amount provider-fee) BPS))
      (y-amount-fees-total (+ y-amount-fees-protocol y-amount-fees-provider))
      (dy (- stx-amount y-amount-fees-total))
      (updated-y-balance (+ y-balance dy))
      (dx (/ (* x-balance dy) updated-y-balance))
    )
    dx
  )
)

(define-read-only (simulate-token-to-stx-bitflow (token-amount uint))
  (let (
      (pool (unwrap-panic (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-fakfun-stx-v-1-1
        get-pool
      )))
      (x-balance (get x-balance pool))
      (y-balance (get y-balance pool))
      (protocol-fee (get x-protocol-fee pool))
      (provider-fee (get x-provider-fee pool))
      (BPS u10000)
      (x-amount-fees-protocol (/ (* token-amount protocol-fee) BPS))
      (x-amount-fees-provider (/ (* token-amount provider-fee) BPS))
      (x-amount-fees-total (+ x-amount-fees-protocol x-amount-fees-provider))
      (dx (- token-amount x-amount-fees-total))
      (updated-x-balance (+ x-balance dx))
      (dy (/ (* y-balance dx) updated-x-balance))
    )
    dy
  )
)

(define-read-only (simulate-sbtc-to-stx-velar (sbtc-amount uint))
  (let (
      (pool (unwrap-panic (contract-call?
        'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070
        get-pool
      )))
      (r0 (get reserve0 pool))
      (r1 (get reserve1 pool))
      (amt-in-adjusted (/ (* sbtc-amount u997) u1000))
      (amt-out (/ (* r0 amt-in-adjusted) (+ r1 amt-in-adjusted)))
    )
    amt-out
  )
)

(define-read-only (simulate-stx-to-sbtc-velar (stx-amount uint))
  (let (
      (pool (unwrap-panic (contract-call?
        'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070
        get-pool
      )))
      (r0 (get reserve0 pool))
      (r1 (get reserve1 pool))
      (amt-in-adjusted (/ (* stx-amount u997) u1000))
      (amt-out (/ (* r1 amt-in-adjusted) (+ r0 amt-in-adjusted)))
    )
    amt-out
  )
)

;; --- Rescue (deployer only) ---

(define-public (rescue-sbtc (amount uint))
  (begin
    (asserts! (is-eq tx-sender DEPLOYER) ERR-NOT-AUTHORIZED)
    (as-contract? ((with-ft SBTC SBTC-ASSET amount))
      (try! (contract-call? SBTC transfer amount current-contract DEPLOYER none))
    )
  )
)

(define-public (rescue-token (amount uint))
  (begin
    (asserts! (is-eq tx-sender DEPLOYER) ERR-NOT-AUTHORIZED)
    (as-contract? ((with-ft TOKEN TOKEN-ASSET amount))
      (try! (contract-call? TOKEN transfer amount current-contract DEPLOYER none))
    )
  )
)

(define-public (rescue-stx (amount uint))
  (begin
    (asserts! (is-eq tx-sender DEPLOYER) ERR-NOT-AUTHORIZED)
    (as-contract? ((with-stx amount))
      (try! (stx-transfer? amount current-contract DEPLOYER))
    )
  )
)
