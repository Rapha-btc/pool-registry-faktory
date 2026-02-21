;; Arbitrage: LEO -> sBTC -> STX -> LEO
;; Routes through fakfun-core-v2 (emits DB events)
;; LEO has three TOKEN-STX DEXes: Bitflow (routes 1-2), Velar (routes 3-4), ALEX (routes 5-8)
;; ALEX routes are 4-leg: LEO↔sBTC (Faktory) + sBTC↔STX (Bitflow/Velar) + STX↔ALEX↔LEO (ALEX 2-hop)
;; Keeps profits (no SAINT burn)

(define-constant ERR-SLIPPAGE (err u1000))
(define-constant ERR-NO-PROFIT (err u1001))
(define-constant ERR-NOT-AUTHORIZED (err u1002))

(define-constant DEPLOYER tx-sender)
(define-constant CONTRACT (as-contract tx-sender))

(define-constant VELAR-POOL-ID u28)

(define-public (arb-fak-bit-bit
    (amt-in uint)
    (min-amt-out uint))
  (begin
    (try! (contract-call?
      'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
      transfer
      amt-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((sbtc-out (try! (as-contract (swap-token-to-sbtc amt-in))))
          (stx-out (try! (as-contract (swap-sbtc-to-stx sbtc-out))))
          (amt-out (try! (as-contract (swap-stx-to-token-bitflow stx-out)))))
          (asserts! (>= amt-out min-amt-out) ERR-SLIPPAGE)
          (asserts! (> amt-out amt-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
            transfer
            amt-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: amt-in,
            token-out: amt-out
          })
        )
      )
    )

(define-private (swap-token-to-sbtc (amount uint))
  (let (
      (result (try! (contract-call?
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-core-v2
        execute
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.leo-faktory-pool-v2
        amount
        (some 0x01)
      )))
      (raw-dy (get dy result))
    )
    (ok (- raw-dy (/ raw-dy u1000)))
  )
)

(define-private (swap-sbtc-to-stx (sbtc-amount uint))
  (let (
      (dy (try! (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2
        swap-x-for-y
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1
        'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2
        sbtc-amount
        u1
      )))
    )
    (ok dy)
  )
)

(define-private (swap-stx-to-token-velar (stx-amount uint))
  (let (
      (result (try! (contract-call?
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-router
        swap-exact-tokens-for-tokens
        VELAR-POOL-ID
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx
        'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx
        'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to
        stx-amount
        u1
      )))
    )
    (ok (get amt-out result))
  )
)

(define-public (arb-fak-vel-vel
    (amt-in uint)
    (min-amt-out uint))
  (begin
    (try! (contract-call?
      'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
      transfer
      amt-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((sbtc-out (try! (as-contract (swap-token-to-sbtc amt-in))))
          (stx-out (try! (as-contract (swap-sbtc-to-stx-velar sbtc-out))))
          (amt-out (try! (as-contract (swap-stx-to-token-velar stx-out)))))
          (asserts! (>= amt-out min-amt-out) ERR-SLIPPAGE)
          (asserts! (> amt-out amt-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
            transfer
            amt-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: amt-in,
            token-out: amt-out
          })
        )
      )
    )

;; REVEEEEEERSE
(define-public (arb-bit-bit-fak
    (amt-in uint)
    (min-amt-out uint))
  (begin
    (try! (contract-call?
      'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
      transfer
      amt-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((stx-out (try! (as-contract (swap-token-to-stx-bitflow amt-in))))
          (sbtc-out (try! (as-contract (swap-stx-to-sbtc stx-out))))
          (amt-out (try! (as-contract (swap-sbtc-to-token sbtc-out)))))
          (asserts! (>= amt-out min-amt-out) ERR-SLIPPAGE)
          (asserts! (> amt-out amt-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
            transfer
            amt-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: amt-in,
            token-out: amt-out
          })
        )
      )
    )

(define-private (swap-token-to-stx-velar (amount uint))
  (let (
      (result (try! (contract-call?
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-router
        swap-exact-tokens-for-tokens
        VELAR-POOL-ID
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx
        'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
        'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to
        amount
        u1
      )))
    )
    (ok (get amt-out result))
  )
)

(define-private (swap-stx-to-sbtc (stx-amount uint))
  (let (
      (dx (try! (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2
        swap-y-for-x
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1
        'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2
        stx-amount
        u1
      )))
    )
    (ok dx)
  )
)

(define-private (swap-sbtc-to-token (sbtc-amount uint))
  (let (
      (result (try! (contract-call?
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-core-v2
        execute
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.leo-faktory-pool-v2
        sbtc-amount
        (some 0x00)
      )))
    )
    (ok (get dy result))
  )
)

(define-public (arb-vel-vel-fak
    (amt-in uint)
    (min-amt-out uint))
  (begin
    (try! (contract-call?
      'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
      transfer
      amt-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((stx-out (try! (as-contract (swap-token-to-stx-velar amt-in))))
          (sbtc-out (try! (as-contract (swap-stx-to-sbtc-velar stx-out))))
          (amt-out (try! (as-contract (swap-sbtc-to-token sbtc-out)))))
          (asserts! (>= amt-out min-amt-out) ERR-SLIPPAGE)
          (asserts! (> amt-out amt-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
            transfer
            amt-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: amt-in,
            token-out: amt-out
          })
        )
      )
    )

(define-private (swap-sbtc-to-stx-velar (sbtc-amount uint))
  (let (
      (result (try! (contract-call?
        'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070
        swap
        'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx
        'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-fees-v1_0_0-0070
        sbtc-amount
        u1
      )))
    )
    (ok (get amt-out result))
  )
)

(define-private (swap-stx-to-sbtc-velar (stx-amount uint))
  (let (
      (result (try! (contract-call?
        'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070
        swap
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx
        'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
        'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-fees-v1_0_0-0070
        stx-amount
        u1
      )))
    )
    (ok (get amt-out result))
  )
)

;; Bitflow token-STX helpers (LEO has Bitflow LEO-STX pool, PEPE does not)
(define-private (swap-stx-to-token-bitflow (stx-amount uint))
  (let (
      (dx (try! (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2
        swap-y-for-x
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-leo-stx-v-1-1
        'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2
        stx-amount
        u1
      )))
    )
    (ok dx)
  )
)

(define-private (swap-token-to-stx-bitflow (amount uint))
  (let (
      (dy (try! (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2
        swap-x-for-y
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-leo-stx-v-1-1
        'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2
        amount
        u1
      )))
    )
    (ok dy)
  )
)

;; Read-only
(define-read-only (check-fak-bit-bit (amt-in uint))
  (let (
    (sbtc-estimate (simulate-token-to-sbtc amt-in))
    (stx-estimate (simulate-sbtc-to-stx sbtc-estimate))
    (amt-estimate (simulate-stx-to-token-bitflow stx-estimate))
    (profit (if (> amt-estimate amt-in) (- amt-estimate amt-in) u0))
  )
  (ok {
    amt-in: amt-in,
    sbtc-out: sbtc-estimate,
    stx-out: stx-estimate,
    amt-out: amt-estimate,
    profit: profit,
    profitable: (> amt-estimate amt-in)
  }))
)

(define-read-only (check-bit-bit-fak (amt-in uint))
  (let (
    (stx-estimate (simulate-token-to-stx-bitflow amt-in))
    (sbtc-estimate (simulate-stx-to-sbtc stx-estimate))
    (amt-estimate (simulate-sbtc-to-token sbtc-estimate))
    (profit (if (> amt-estimate amt-in) (- amt-estimate amt-in) u0))
  )
  (ok {
    amt-in: amt-in,
    stx-out: stx-estimate,
    sbtc-out: sbtc-estimate,
    amt-out: amt-estimate,
    profit: profit,
    profitable: (> amt-estimate amt-in)
  }))
)

(define-read-only (simulate-token-to-sbtc (amount uint))
  (let ((raw-dy (get dy (unwrap-panic (contract-call?
    'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.leo-faktory-pool-v2
    quote
    amount
    (some 0x01)
  )))))
  (- raw-dy (/ raw-dy u1000)))
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

(define-read-only (simulate-stx-to-token-velar (stx-amount uint))
  (let ((pool (unwrap-panic (contract-call?
          'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-core
          get-pool
          VELAR-POOL-ID)))
        (r0 (get reserve0 pool))
        (r1 (get reserve1 pool))
        (swap-fee (get swap-fee pool))
        (amt-in-adjusted (/ (* stx-amount (get num swap-fee)) (get den swap-fee)))
        (amt-out (/ (* r1 amt-in-adjusted) (+ r0 amt-in-adjusted)))
  )
  amt-out)
)

(define-read-only (simulate-token-to-stx-velar (amount uint))
  (let ((pool (unwrap-panic (contract-call?
          'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-core
          get-pool
          VELAR-POOL-ID)))
        (r0 (get reserve0 pool))
        (r1 (get reserve1 pool))
        (swap-fee (get swap-fee pool))
        (amt-in-adjusted (/ (* amount (get num swap-fee)) (get den swap-fee)))
        (amt-out (/ (* r0 amt-in-adjusted) (+ r1 amt-in-adjusted)))
  )
  amt-out)
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

(define-read-only (simulate-sbtc-to-token (sbtc-amount uint))
  ;; A-to-B: quote already nets FAKTORY_FEE from sBTC input
  (get dy (unwrap-panic (contract-call?
    'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.leo-faktory-pool-v2
    quote
    sbtc-amount
    (some 0x00)
  )))
)

(define-read-only (simulate-sbtc-to-stx-velar (sbtc-amount uint))
  (let ((pool (unwrap-panic (contract-call?
          'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070
          get-pool)))
        (r0 (get reserve0 pool)) ;; STX
        (r1 (get reserve1 pool)) ;; sBTC
        ;; Velar fee: 0.3% = 997/1000 of input remains after fee
        (amt-in-adjusted (/ (* sbtc-amount u997) u1000))
        (amt-out (/ (* r0 amt-in-adjusted) (+ r1 amt-in-adjusted)))
  )
  amt-out)
)

(define-read-only (simulate-stx-to-sbtc-velar (stx-amount uint))
  (let ((pool (unwrap-panic (contract-call?
          'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070
          get-pool)))
        (r0 (get reserve0 pool)) ;; STX
        (r1 (get reserve1 pool)) ;; sBTC
        ;; Velar fee: 0.3% = 997/1000 of input remains after fee
        (amt-in-adjusted (/ (* stx-amount u997) u1000))
        (amt-out (/ (* r1 amt-in-adjusted) (+ r0 amt-in-adjusted)))
  )
  amt-out)
)

;; Bitflow simulate helpers (LEO has Bitflow LEO-STX pool, PEPE does not)
(define-read-only (simulate-stx-to-token-bitflow (stx-amount uint))
  (let (
      (pool (unwrap-panic (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-leo-stx-v-1-1
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

(define-read-only (simulate-token-to-stx-bitflow (amount uint))
  (let (
      (pool (unwrap-panic (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-leo-stx-v-1-1
        get-pool
      )))
      (x-balance (get x-balance pool))
      (y-balance (get y-balance pool))
      (protocol-fee (get x-protocol-fee pool))
      (provider-fee (get x-provider-fee pool))
      (BPS u10000)
      (x-amount-fees-protocol (/ (* amount protocol-fee) BPS))
      (x-amount-fees-provider (/ (* amount provider-fee) BPS))
      (x-amount-fees-total (+ x-amount-fees-protocol x-amount-fees-provider))
      (dx (- amount x-amount-fees-total))
      (updated-x-balance (+ x-balance dx))
      (dy (/ (* y-balance dx) updated-x-balance))
    )
    dy
  )
)

(define-read-only (check-fak-vel-vel (amt-in uint))
  (let (
    (sbtc-estimate (simulate-token-to-sbtc amt-in))
    (stx-estimate (simulate-sbtc-to-stx-velar sbtc-estimate))
    (amt-estimate (simulate-stx-to-token-velar stx-estimate))
    (profit (if (> amt-estimate amt-in) (- amt-estimate amt-in) u0))
  )
  (ok {
    amt-in: amt-in,
    sbtc-out: sbtc-estimate,
    stx-out: stx-estimate,
    amt-out: amt-estimate,
    profit: profit,
    profitable: (> amt-estimate amt-in)
  }))
)

(define-read-only (check-vel-vel-fak (amt-in uint))
  (let (
    (stx-estimate (simulate-token-to-stx-velar amt-in))
    (sbtc-estimate (simulate-stx-to-sbtc-velar stx-estimate))
    (amt-estimate (simulate-sbtc-to-token sbtc-estimate))
    (profit (if (> amt-estimate amt-in) (- amt-estimate amt-in) u0))
  )
  (ok {
    amt-in: amt-in,
    stx-out: stx-estimate,
    sbtc-out: sbtc-estimate,
    amt-out: amt-estimate,
    profit: profit,
    profitable: (> amt-estimate amt-in)
  }))
)


(define-constant ALEX-FACTOR u100000000)

(define-private (swap-stx-to-token-alex (stx-amount uint))
  (let (
    (token-8dec (try! (contract-call?
      'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01
      swap-helper-a
      'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v2
      'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex
      'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wleo
      ALEX-FACTOR
      ALEX-FACTOR
      (* stx-amount u100)
      none
    )))
  )
  (ok (/ token-8dec u100)))
)

(define-private (swap-token-to-stx-alex (amount uint))
  (let (
    (stx-8dec (try! (contract-call?
      'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01
      swap-helper-a
      'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wleo
      'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex
      'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v2
      ALEX-FACTOR
      ALEX-FACTOR
      (* amount u100)
      none
    )))
  )
  (ok (/ stx-8dec u100)))
)

(define-public (arb-fak-bit-alex
    (amt-in uint)
    (min-amt-out uint))
  (begin
    (try! (contract-call?
      'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
      transfer
      amt-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((sbtc-out (try! (as-contract (swap-token-to-sbtc amt-in))))
          (stx-out (try! (as-contract (swap-sbtc-to-stx sbtc-out))))
          (amt-out (try! (as-contract (swap-stx-to-token-alex stx-out)))))

          (asserts! (>= amt-out min-amt-out) ERR-SLIPPAGE)
          (asserts! (> amt-out amt-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
            transfer
            amt-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: amt-in,
            token-out: amt-out
          })
        )
      )
    )

(define-public (arb-fak-vel-alex
    (amt-in uint)
    (min-amt-out uint))
  (begin
    (try! (contract-call?
      'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
      transfer
      amt-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((sbtc-out (try! (as-contract (swap-token-to-sbtc amt-in))))
          (stx-out (try! (as-contract (swap-sbtc-to-stx-velar sbtc-out))))
          (amt-out (try! (as-contract (swap-stx-to-token-alex stx-out)))))

          (asserts! (>= amt-out min-amt-out) ERR-SLIPPAGE)
          (asserts! (> amt-out amt-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
            transfer
            amt-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: amt-in,
            token-out: amt-out
          })
        )
      )
    )

(define-public (arb-alex-bit-fak
    (amt-in uint)
    (min-amt-out uint))
  (begin
    (try! (contract-call?
      'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
      transfer
      amt-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((stx-out (try! (as-contract (swap-token-to-stx-alex amt-in))))
          (sbtc-out (try! (as-contract (swap-stx-to-sbtc stx-out))))
          (amt-out (try! (as-contract (swap-sbtc-to-token sbtc-out)))))

          (asserts! (>= amt-out min-amt-out) ERR-SLIPPAGE)
          (asserts! (> amt-out amt-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
            transfer
            amt-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: amt-in,
            token-out: amt-out
          })
        )
      )
    )

(define-public (arb-alex-vel-fak
    (amt-in uint)
    (min-amt-out uint))
  (begin
    (try! (contract-call?
      'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
      transfer
      amt-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((stx-out (try! (as-contract (swap-token-to-stx-alex amt-in))))
          (sbtc-out (try! (as-contract (swap-stx-to-sbtc-velar stx-out))))
          (amt-out (try! (as-contract (swap-sbtc-to-token sbtc-out)))))

          (asserts! (>= amt-out min-amt-out) ERR-SLIPPAGE)
          (asserts! (> amt-out amt-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
            transfer
            amt-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: amt-in,
            token-out: amt-out
          })
        )
      )
    )

(define-read-only (simulate-stx-to-token-alex (stx-amount uint))
  (/ (unwrap-panic (contract-call?
    'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01
    get-helper-a
    'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v2
    'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex
    'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wleo
    ALEX-FACTOR
    ALEX-FACTOR
    (* stx-amount u100)
  )) u100)
)

(define-read-only (simulate-token-to-stx-alex (amount uint))
  (/ (unwrap-panic (contract-call?
    'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01
    get-helper-a
    'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wleo
    'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex
    'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v2
    ALEX-FACTOR
    ALEX-FACTOR
    (* amount u100)
  )) u100)
)

(define-read-only (check-fak-bit-alex (amt-in uint))
  (let (
    (sbtc-estimate (simulate-token-to-sbtc amt-in))
    (stx-estimate (simulate-sbtc-to-stx sbtc-estimate))
    (amt-estimate (simulate-stx-to-token-alex stx-estimate))
    (profit (if (> amt-estimate amt-in) (- amt-estimate amt-in) u0))
  )
  (ok {
    amt-in: amt-in,
    sbtc-out: sbtc-estimate,
    stx-out: stx-estimate,
    amt-out: amt-estimate,
    profit: profit,
    profitable: (> amt-estimate amt-in)
  }))
)

(define-read-only (check-fak-vel-alex (amt-in uint))
  (let (
    (sbtc-estimate (simulate-token-to-sbtc amt-in))
    (stx-estimate (simulate-sbtc-to-stx-velar sbtc-estimate))
    (amt-estimate (simulate-stx-to-token-alex stx-estimate))
    (profit (if (> amt-estimate amt-in) (- amt-estimate amt-in) u0))
  )
  (ok {
    amt-in: amt-in,
    sbtc-out: sbtc-estimate,
    stx-out: stx-estimate,
    amt-out: amt-estimate,
    profit: profit,
    profitable: (> amt-estimate amt-in)
  }))
)

(define-read-only (check-alex-bit-fak (amt-in uint))
  (let (
    (stx-estimate (simulate-token-to-stx-alex amt-in))
    (sbtc-estimate (simulate-stx-to-sbtc stx-estimate))
    (amt-estimate (simulate-sbtc-to-token sbtc-estimate))
    (profit (if (> amt-estimate amt-in) (- amt-estimate amt-in) u0))
  )
  (ok {
    amt-in: amt-in,
    stx-out: stx-estimate,
    sbtc-out: sbtc-estimate,
    amt-out: amt-estimate,
    profit: profit,
    profitable: (> amt-estimate amt-in)
  }))
)

(define-read-only (check-alex-vel-fak (amt-in uint))
  (let (
    (stx-estimate (simulate-token-to-stx-alex amt-in))
    (sbtc-estimate (simulate-stx-to-sbtc-velar stx-estimate))
    (amt-estimate (simulate-sbtc-to-token sbtc-estimate))
    (profit (if (> amt-estimate amt-in) (- amt-estimate amt-in) u0))
  )
  (ok {
    amt-in: amt-in,
    stx-out: stx-estimate,
    sbtc-out: sbtc-estimate,
    amt-out: amt-estimate,
    profit: profit,
    profitable: (> amt-estimate amt-in)
  }))
)

;; --- Rescue functions (deployer only) ---

(define-public (rescue-sbtc (amount uint))
  (begin
    (asserts! (is-eq tx-sender DEPLOYER) ERR-NOT-AUTHORIZED)
    (as-contract (contract-call?
      'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      transfer
      amount
      CONTRACT
      DEPLOYER
      none
    ))
  )
)

(define-public (rescue-token (amount uint))
  (begin
    (asserts! (is-eq tx-sender DEPLOYER) ERR-NOT-AUTHORIZED)
    (as-contract (contract-call?
      'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
      transfer
      amount
      CONTRACT
      DEPLOYER
      none
    ))
  )
)
