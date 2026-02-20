;; Arbitrage: LEO -> sBTC -> STX -> LEO
;; Routes through fakfun-core-v2 (emits DB events)
;; LEO has two TOKEN-STX DEXes: Bitflow (routes 1-2) and Velar (routes 3-4)
;; Keeps profits (no SAINT burn)

(define-constant ERR-SLIPPAGE (err u1000))
(define-constant ERR-NO-PROFIT (err u1001))

(define-constant DEPLOYER tx-sender)
(define-constant CONTRACT (as-contract tx-sender))

(define-constant VELAR-POOL-ID u28)

(define-public (arb-fak-bit-bit
    (leo-in uint)
    (min-leo-out uint))
  (begin
    (try! (contract-call?
      'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
      transfer
      leo-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((sbtc-out (try! (as-contract (swap-leo-to-sbtc leo-in))))
          (stx-out (try! (as-contract (swap-sbtc-to-stx sbtc-out))))
          (leo-out (try! (as-contract (swap-stx-to-leo-bitflow stx-out)))))

          (asserts! (>= leo-out min-leo-out) ERR-SLIPPAGE)
          (asserts! (> leo-out leo-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
            transfer
            leo-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: leo-in,
            token-out: leo-out
          })
        )
      )
    )

(define-private (swap-leo-to-sbtc (leo-amount uint))
  (let (
      (result (try! (contract-call?
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-core-v2
        execute
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.leo-faktory-pool-v2
        leo-amount
        (some 0x01)
      )))
    )
    (ok (get dy result))
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

(define-private (swap-stx-to-leo-bitflow (stx-amount uint))
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

(define-public (arb-fak-vel-vel
    (leo-in uint)
    (min-leo-out uint))
  (begin
    (try! (contract-call?
      'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
      transfer
      leo-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((sbtc-out (try! (as-contract (swap-leo-to-sbtc leo-in))))
          (stx-out (try! (as-contract (swap-sbtc-to-stx-velar sbtc-out))))
          (leo-out (try! (as-contract (swap-stx-to-leo-velar stx-out)))))

          (asserts! (>= leo-out min-leo-out) ERR-SLIPPAGE)
          (asserts! (> leo-out leo-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
            transfer
            leo-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: leo-in,
            token-out: leo-out
          })
        )
      )
    )

;; REVEEEEEERSE
(define-public (arb-bit-bit-fak
    (leo-in uint)
    (min-leo-out uint))
  (begin
    (try! (contract-call?
      'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
      transfer
      leo-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((stx-out (try! (as-contract (swap-leo-to-stx-bitflow leo-in))))
          (sbtc-out (try! (as-contract (swap-stx-to-sbtc stx-out))))
          (leo-out (try! (as-contract (swap-sbtc-to-leo sbtc-out)))))

          (asserts! (>= leo-out min-leo-out) ERR-SLIPPAGE)
          (asserts! (> leo-out leo-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
            transfer
            leo-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: leo-in,
            token-out: leo-out
          })
        )
      )
    )

(define-private (swap-leo-to-stx-bitflow (leo-amount uint))
  (let (
      (dy (try! (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2
        swap-x-for-y
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-leo-stx-v-1-1
        'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2
        leo-amount
        u1
      )))
    )
    (ok dy)
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

(define-private (swap-sbtc-to-leo (sbtc-amount uint))
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
    (leo-in uint)
    (min-leo-out uint))
  (begin
    (try! (contract-call?
      'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
      transfer
      leo-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((stx-out (try! (as-contract (swap-leo-to-stx-velar leo-in))))
          (sbtc-out (try! (as-contract (swap-stx-to-sbtc-velar stx-out))))
          (leo-out (try! (as-contract (swap-sbtc-to-leo sbtc-out)))))

          (asserts! (>= leo-out min-leo-out) ERR-SLIPPAGE)
          (asserts! (> leo-out leo-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token
            transfer
            leo-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: leo-in,
            token-out: leo-out
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

(define-private (swap-stx-to-leo-velar (stx-amount uint))
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

(define-private (swap-leo-to-stx-velar (leo-amount uint))
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
        leo-amount
        u1
      )))
    )
    (ok (get amt-out result))
  )
)

;; Read-only
(define-read-only (check-fak-bit-bit (leo-in uint))
  (let (
    (sbtc-estimate (simulate-leo-to-sbtc leo-in))
    (stx-estimate (simulate-sbtc-to-stx sbtc-estimate))
    (leo-estimate (simulate-stx-to-leo-bitflow stx-estimate))
    (profit (if (> leo-estimate leo-in) (- leo-estimate leo-in) u0))
  )
  (ok {
    leo-in: leo-in,
    sbtc-out: sbtc-estimate,
    stx-out: stx-estimate,
    leo-out: leo-estimate,
    profit: profit,
    profitable: (> leo-estimate leo-in)
  }))
)

(define-read-only (check-bit-bit-fak (leo-in uint))
  (let (
    (stx-estimate (simulate-leo-to-stx-bitflow leo-in))
    (sbtc-estimate (simulate-stx-to-sbtc stx-estimate))
    (leo-estimate (simulate-sbtc-to-leo sbtc-estimate))
    (profit (if (> leo-estimate leo-in) (- leo-estimate leo-in) u0))
  )
  (ok {
    leo-in: leo-in,
    stx-out: stx-estimate,
    sbtc-out: sbtc-estimate,
    leo-out: leo-estimate,
    profit: profit,
    profitable: (> leo-estimate leo-in)
  }))
)

(define-read-only (simulate-leo-to-sbtc (leo-amount uint))
  (get dy (unwrap-panic (contract-call?
    'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.leo-faktory-pool-v2
    quote
    leo-amount
    (some 0x01)
  )))
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

(define-read-only (simulate-stx-to-leo-bitflow (stx-amount uint))
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

(define-read-only (simulate-leo-to-stx-bitflow (leo-amount uint))
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
      (x-amount-fees-protocol (/ (* leo-amount protocol-fee) BPS))
      (x-amount-fees-provider (/ (* leo-amount provider-fee) BPS))
      (x-amount-fees-total (+ x-amount-fees-protocol x-amount-fees-provider))
      (dx (- leo-amount x-amount-fees-total))
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

(define-read-only (simulate-sbtc-to-leo (sbtc-amount uint))
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

(define-read-only (simulate-stx-to-leo-velar (stx-amount uint))
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

(define-read-only (simulate-leo-to-stx-velar (leo-amount uint))
  (let ((pool (unwrap-panic (contract-call?
          'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-core
          get-pool
          VELAR-POOL-ID)))
        (r0 (get reserve0 pool))
        (r1 (get reserve1 pool))
        (swap-fee (get swap-fee pool))
        (amt-in-adjusted (/ (* leo-amount (get num swap-fee)) (get den swap-fee)))
        (amt-out (/ (* r0 amt-in-adjusted) (+ r1 amt-in-adjusted)))
  )
  amt-out)
)

(define-read-only (check-fak-vel-vel (leo-in uint))
  (let (
    (sbtc-estimate (simulate-leo-to-sbtc leo-in))
    (stx-estimate (simulate-sbtc-to-stx-velar sbtc-estimate))
    (leo-estimate (simulate-stx-to-leo-velar stx-estimate))
    (profit (if (> leo-estimate leo-in) (- leo-estimate leo-in) u0))
  )
  (ok {
    leo-in: leo-in,
    sbtc-out: sbtc-estimate,
    stx-out: stx-estimate,
    leo-out: leo-estimate,
    profit: profit,
    profitable: (> leo-estimate leo-in)
  }))
)

(define-read-only (check-vel-vel-fak (leo-in uint))
  (let (
    (stx-estimate (simulate-leo-to-stx-velar leo-in))
    (sbtc-estimate (simulate-stx-to-sbtc-velar stx-estimate))
    (leo-estimate (simulate-sbtc-to-leo sbtc-estimate))
    (profit (if (> leo-estimate leo-in) (- leo-estimate leo-in) u0))
  )
  (ok {
    leo-in: leo-in,
    stx-out: stx-estimate,
    sbtc-out: sbtc-estimate,
    leo-out: leo-estimate,
    profit: profit,
    profitable: (> leo-estimate leo-in)
  }))
)
