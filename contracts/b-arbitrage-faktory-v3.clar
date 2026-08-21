;; SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-arbitrage-faktory-v3
;; v2's B arithmetic, ported to the mia-arbitrage-faktory pattern:
;;   - profit swept to DEPLOYER (= deploy tx-sender = chavita), NOT to SAINT
;;   - named constants for every principal
;;   - Clarity 5 in-contract post-conditions: each leg runs under as-contract?
;;     with a with-ft / with-stx allowance for exactly that leg's input
;;   - B is 8-dec and wbfaktory is 8-dec, so (unlike mia 6-dec) the ALEX legs
;;     do NOT scale the B side; the STX side still uses * u100 / (/ u100)
;;   - b-faktory-pool.execute is a DIRECT 2-arg (amount, opcode) call and its
;;     dy is exact (no fee shave, matching v2)
;; Bridges (sBTC<->STX): Bitflow XYK, Velar. Profit-or-revert.

(define-constant ERR-SLIPPAGE (err u1000))
(define-constant ERR-NO-PROFIT (err u1001))
(define-constant ERR-NOT-AUTHORIZED (err u1002))

(define-constant DEPLOYER tx-sender)
(define-constant B 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory)
(define-constant B-ASSET "B")
(define-constant B-POOL 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory-pool)
(define-constant SBTC 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token)
(define-constant SBTC-ASSET "sbtc-token")
(define-constant XYK-CORE 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2)
(define-constant XYK-POOL 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1)
(define-constant STX-TOKEN 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2)
(define-constant ALEX-POOL 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01)
(define-constant WSTX-V2 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v2)
(define-constant WBFAKTORY 'SP1KK89R86W73SJE6RQNQPRDM471008S9JY4FQA62.token-wbfaktory)
(define-constant VELAR-POOL 'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070)
(define-constant VELAR-FEES 'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-fees-v1_0_0-0070)
(define-constant WSTX 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx)

;; ---- forward: fak -> bridge -> alex ----

(define-public (arb-fak-bit-alex
    (token-in uint)
    (min-token-out uint)
  )
  (begin
    (try! (contract-call? B transfer token-in tx-sender current-contract none))
    (let (
        (sbtc-out (try! (as-contract? ((with-ft B B-ASSET token-in))
          (try! (swap-token-to-sbtc token-in))
        )))
        (stx-out (try! (as-contract? ((with-ft SBTC SBTC-ASSET sbtc-out))
          (try! (swap-sbtc-to-stx sbtc-out))
        )))
        (token-out (try! (as-contract? ((with-stx stx-out))
          (try! (swap-stx-to-token (* stx-out u100)))
        )))
      )
      (asserts! (>= token-out min-token-out) ERR-SLIPPAGE)
      (asserts! (> token-out token-in) ERR-NO-PROFIT)
      (try! (back-to-deployer token-out))
      (ok {
        token-in: token-in,
        token-out: token-out,
      })
    )
  )
)

(define-public (arb-fak-vel-alex
    (token-in uint)
    (min-token-out uint)
  )
  (begin
    (try! (contract-call? B transfer token-in tx-sender current-contract none))
    (let (
        (sbtc-out (try! (as-contract? ((with-ft B B-ASSET token-in))
          (try! (swap-token-to-sbtc token-in))
        )))
        (stx-out (try! (as-contract? ((with-ft SBTC SBTC-ASSET sbtc-out))
          (try! (swap-sbtc-to-stx-velar sbtc-out))
        )))
        (token-out (try! (as-contract? ((with-stx stx-out))
          (try! (swap-stx-to-token (* stx-out u100)))
        )))
      )
      (asserts! (>= token-out min-token-out) ERR-SLIPPAGE)
      (asserts! (> token-out token-in) ERR-NO-PROFIT)
      (try! (back-to-deployer token-out))
      (ok {
        token-in: token-in,
        token-out: token-out,
      })
    )
  )
)

;; ---- reverse: alex -> bridge -> fak ----

(define-public (arb-alex-bit-fak
    (token-in uint)
    (min-token-out uint)
  )
  (begin
    (try! (contract-call? B transfer token-in tx-sender current-contract none))
    (let (
        (stx-out (try! (as-contract? ((with-ft B B-ASSET token-in))
          (try! (swap-token-to-stx token-in))
        )))
        (sbtc-out (try! (as-contract? ((with-stx (/ stx-out u100)))
          (try! (swap-stx-to-sbtc (/ stx-out u100)))
        )))
        (token-out (try! (as-contract? ((with-ft SBTC SBTC-ASSET sbtc-out))
          (try! (swap-sbtc-to-token sbtc-out))
        )))
      )
      (asserts! (>= token-out min-token-out) ERR-SLIPPAGE)
      (asserts! (> token-out token-in) ERR-NO-PROFIT)
      (try! (back-to-deployer token-out))
      (ok {
        token-in: token-in,
        token-out: token-out,
      })
    )
  )
)

(define-public (arb-alex-vel-fak
    (token-in uint)
    (min-token-out uint)
  )
  (begin
    (try! (contract-call? B transfer token-in tx-sender current-contract none))
    (let (
        (stx-out (try! (as-contract? ((with-ft B B-ASSET token-in))
          (try! (swap-token-to-stx token-in))
        )))
        (sbtc-out (try! (as-contract? ((with-stx (/ stx-out u100)))
          (try! (swap-stx-to-sbtc-velar (/ stx-out u100)))
        )))
        (token-out (try! (as-contract? ((with-ft SBTC SBTC-ASSET sbtc-out))
          (try! (swap-sbtc-to-token sbtc-out))
        )))
      )
      (asserts! (>= token-out min-token-out) ERR-SLIPPAGE)
      (asserts! (> token-out token-in) ERR-NO-PROFIT)
      (try! (back-to-deployer token-out))
      (ok {
        token-in: token-in,
        token-out: token-out,
      })
    )
  )
)

;; ---- return profit to deployer (= keeper caller = chavita) ----

(define-private (back-to-deployer (amt uint))
  (as-contract? ((with-ft B B-ASSET amt))
    (try! (contract-call? B transfer amt current-contract DEPLOYER none))
  )
)

;; ---- swap legs (callers wrap each in as-contract? with the leg's allowance) ----

(define-private (swap-token-to-sbtc (amount uint))
  (let ((result (try! (contract-call? B-POOL execute amount (some 0x01)))))
    (ok (get dy result))
  )
)

(define-private (swap-sbtc-to-token (amount uint))
  (let ((result (try! (contract-call? B-POOL execute amount (some 0x00)))))
    (ok (get dy result))
  )
)

(define-private (swap-sbtc-to-stx (sbtc-amount uint))
  (let ((dy (try! (contract-call? XYK-CORE swap-x-for-y XYK-POOL SBTC STX-TOKEN sbtc-amount u1))))
    (ok dy)
  )
)

(define-private (swap-stx-to-sbtc (stx-amount uint))
  (let ((dx (try! (contract-call? XYK-CORE swap-y-for-x XYK-POOL SBTC STX-TOKEN stx-amount u1))))
    (ok dx)
  )
)

(define-private (swap-stx-to-token (stx-amount uint))
  (let ((result (try! (contract-call? ALEX-POOL swap-x-for-y WSTX-V2 WBFAKTORY u100000000
      stx-amount none
    ))))
    (ok (get dy result))
  )
)

(define-private (swap-token-to-stx (token-amount uint))
  (let ((result (try! (contract-call? ALEX-POOL swap-y-for-x WSTX-V2 WBFAKTORY u100000000
      token-amount none
    ))))
    (ok (get dx result))
  )
)

(define-private (swap-sbtc-to-stx-velar (sbtc-amount uint))
  (let ((result (try! (contract-call? VELAR-POOL swap SBTC WSTX VELAR-FEES sbtc-amount u1))))
    (ok (get amt-out result))
  )
)

(define-private (swap-stx-to-sbtc-velar (stx-amount uint))
  (let ((result (try! (contract-call? VELAR-POOL swap WSTX SBTC VELAR-FEES stx-amount u1))))
    (ok (get amt-out result))
  )
)

;; ---- simulations (read-only; keeper polls; literal callees required) ----

(define-read-only (simulate-token-to-sbtc (token-amount uint))
  (get dy
    (unwrap-panic (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory-pool
      quote token-amount (some 0x01)
    ))
  )
)

(define-read-only (simulate-sbtc-to-token (sbtc-amount uint))
  (get dy
    (unwrap-panic (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory-pool
      quote sbtc-amount (some 0x00)
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

(define-read-only (simulate-stx-to-token (stx-amount uint))
  (let (
      (fee (/ (+ (* stx-amount u500000) u99999999) u100000000))
      (stx-net (if (<= stx-amount fee)
        u0
        (- stx-amount fee)
      ))
    )
    (unwrap-panic (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01
      get-y-given-x 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v2
      'SP1KK89R86W73SJE6RQNQPRDM471008S9JY4FQA62.token-wbfaktory u100000000
      stx-net
    ))
  )
)

(define-read-only (simulate-token-to-stx (token-amount uint))
  (let (
      (fee (/ (+ (* token-amount u500000) u99999999) u100000000))
      (token-net (if (<= token-amount fee)
        u0
        (- token-amount fee)
      ))
    )
    (unwrap-panic (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01
      get-x-given-y 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v2
      'SP1KK89R86W73SJE6RQNQPRDM471008S9JY4FQA62.token-wbfaktory u100000000
      token-net
    ))
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

;; ---- profitability checks (keeper entry points) ----

(define-read-only (check-fak-bit-alex (token-in uint))
  (let (
      (sbtc-estimate (simulate-token-to-sbtc token-in))
      (stx-estimate (simulate-sbtc-to-stx sbtc-estimate))
      (token-estimate (simulate-stx-to-token (* stx-estimate u100)))
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

(define-read-only (check-fak-vel-alex (token-in uint))
  (let (
      (sbtc-estimate (simulate-token-to-sbtc token-in))
      (stx-estimate (simulate-sbtc-to-stx-velar sbtc-estimate))
      (token-estimate (simulate-stx-to-token (* stx-estimate u100)))
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

(define-read-only (check-alex-bit-fak (token-in uint))
  (let (
      (stx-estimate (/ (simulate-token-to-stx token-in) u100))
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

(define-read-only (check-alex-vel-fak (token-in uint))
  (let (
      (stx-estimate (/ (simulate-token-to-stx token-in) u100))
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

;; ---- rescue ----

(define-public (rescue-b (amount uint))
  (begin
    (asserts! (is-eq tx-sender DEPLOYER) ERR-NOT-AUTHORIZED)
    (as-contract? ((with-ft B B-ASSET amount))
      (try! (contract-call? B transfer amount current-contract DEPLOYER none))
    )
  )
)

(define-public (rescue-sbtc (amount uint))
  (begin
    (asserts! (is-eq tx-sender DEPLOYER) ERR-NOT-AUTHORIZED)
    (as-contract? ((with-ft SBTC SBTC-ASSET amount))
      (try! (contract-call? SBTC transfer amount current-contract DEPLOYER none))
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
