;; Arbitrage v2: PEPE -> sBTC -> STX -> PEPE
;; Routes through fakfun-core-v2 (emits DB events)
;; Keeps profits (no SAINT burn)

(define-constant ERR-SLIPPAGE (err u1000))
(define-constant ERR-NO-PROFIT (err u1001))

(define-constant DEPLOYER tx-sender)
(define-constant CONTRACT (as-contract tx-sender))

(define-constant VELAR-POOL-ID u11)

(define-public (arb-fak-bit-vel
    (pepe-in uint)
    (min-pepe-out uint))
  (begin
    (try! (contract-call?
      'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
      transfer
      pepe-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((sbtc-out (try! (as-contract (swap-pepe-to-sbtc pepe-in))))
          (stx-out (try! (as-contract (swap-sbtc-to-stx sbtc-out))))
          (pepe-out (try! (as-contract (swap-stx-to-pepe stx-out)))))
          (asserts! (>= pepe-out min-pepe-out) ERR-SLIPPAGE)
          (asserts! (> pepe-out pepe-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
            transfer
            pepe-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: pepe-in,
            token-out: pepe-out
          })
        )
      )
    )

(define-private (swap-pepe-to-sbtc (pepe-amount uint))
  (let (
      (result (try! (contract-call?
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-core-v2
        execute
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.pepe-faktory-pool-v2-2
        pepe-amount
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

(define-private (swap-stx-to-pepe (stx-amount uint))
  (let (
      (result (try! (contract-call?
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-router
        swap-exact-tokens-for-tokens
        VELAR-POOL-ID
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx
        'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx
        'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to
        stx-amount
        u1
      )))
    )
    (ok (get amt-out result))
  )
)

(define-public (arb-fak-vel-vel
    (pepe-in uint)
    (min-pepe-out uint))
  (begin
    (try! (contract-call?
      'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
      transfer
      pepe-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((sbtc-out (try! (as-contract (swap-pepe-to-sbtc pepe-in))))
          (stx-out (try! (as-contract (swap-sbtc-to-stx-velar sbtc-out))))
          (pepe-out (try! (as-contract (swap-stx-to-pepe stx-out)))))
          (asserts! (>= pepe-out min-pepe-out) ERR-SLIPPAGE)
          (asserts! (> pepe-out pepe-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
            transfer
            pepe-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: pepe-in,
            token-out: pepe-out
          })
        )
      )
    )

;; REVEEEEEERSE
(define-public (arb-vel-bit-fak
    (pepe-in uint)
    (min-pepe-out uint))
  (begin
    (try! (contract-call?
      'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
      transfer
      pepe-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((stx-out (try! (as-contract (swap-pepe-to-stx pepe-in))))
          (sbtc-out (try! (as-contract (swap-stx-to-sbtc stx-out))))
          (pepe-out (try! (as-contract (swap-sbtc-to-pepe sbtc-out)))))
          (asserts! (>= pepe-out min-pepe-out) ERR-SLIPPAGE)
          (asserts! (> pepe-out pepe-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
            transfer
            pepe-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: pepe-in,
            token-out: pepe-out
          })
        )
      )
    )

(define-private (swap-pepe-to-stx (pepe-amount uint))
  (let (
      (result (try! (contract-call?
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-router
        swap-exact-tokens-for-tokens
        VELAR-POOL-ID
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx
        'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
        'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to
        pepe-amount
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

(define-private (swap-sbtc-to-pepe (sbtc-amount uint))
  (let (
      (result (try! (contract-call?
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-core-v2
        execute
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.pepe-faktory-pool-v2-2
        sbtc-amount
        (some 0x00)
      )))
    )
    (ok (get dy result))
  )
)

(define-public (arb-vel-vel-fak
    (pepe-in uint)
    (min-pepe-out uint))
  (begin
    (try! (contract-call?
      'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
      transfer
      pepe-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((stx-out (try! (as-contract (swap-pepe-to-stx pepe-in))))
          (sbtc-out (try! (as-contract (swap-stx-to-sbtc-velar stx-out))))
          (pepe-out (try! (as-contract (swap-sbtc-to-pepe sbtc-out)))))
          (asserts! (>= pepe-out min-pepe-out) ERR-SLIPPAGE)
          (asserts! (> pepe-out pepe-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
            transfer
            pepe-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: pepe-in,
            token-out: pepe-out
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

;; Read-only 
(define-read-only (check-fak-bit-vel (pepe-in uint))
  (let (
    (sbtc-estimate (simulate-pepe-to-sbtc pepe-in))
    (stx-estimate (simulate-sbtc-to-stx sbtc-estimate))
    (pepe-estimate (simulate-stx-to-pepe stx-estimate))
    (profit (if (> pepe-estimate pepe-in) (- pepe-estimate pepe-in) u0))
  )
  (ok {
    pepe-in: pepe-in,
    sbtc-out: sbtc-estimate,
    stx-out: stx-estimate,
    pepe-out: pepe-estimate,
    profit: profit,
    profitable: (> pepe-estimate pepe-in)
  }))
)

(define-read-only (check-vel-bit-fak (pepe-in uint))
  (let (
    (stx-estimate (simulate-pepe-to-stx pepe-in))
    (sbtc-estimate (simulate-stx-to-sbtc stx-estimate))
    (pepe-estimate (simulate-sbtc-to-pepe sbtc-estimate))
    (profit (if (> pepe-estimate pepe-in) (- pepe-estimate pepe-in) u0))
  )
  (ok {
    pepe-in: pepe-in,
    stx-out: stx-estimate,
    sbtc-out: sbtc-estimate,
    pepe-out: pepe-estimate,
    profit: profit,
    profitable: (> pepe-estimate pepe-in)
  }))
)

(define-read-only (simulate-pepe-to-sbtc (pepe-amount uint))
  ;; Protocol fee: 1/1000 skimmed from sBTC output
  (/ (* (get dy (unwrap-panic (contract-call?
    'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.pepe-faktory-pool-v2-2
    quote
    pepe-amount
    (some 0x01)
  ))) u999) u1000)
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

(define-read-only (simulate-stx-to-pepe (stx-amount uint))
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

(define-read-only (simulate-pepe-to-stx (pepe-amount uint))
  (let ((pool (unwrap-panic (contract-call? 
          'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-core 
          get-pool 
          VELAR-POOL-ID)))
        (r0 (get reserve0 pool))
        (r1 (get reserve1 pool))
        (swap-fee (get swap-fee pool))
        (amt-in-adjusted (/ (* pepe-amount (get num swap-fee)) (get den swap-fee)))
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

(define-read-only (simulate-sbtc-to-pepe (sbtc-amount uint))
  ;; A-to-B: quote already nets FAKTORY_FEE from sBTC input
  (get dy (unwrap-panic (contract-call?
    'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.pepe-faktory-pool-v2-2
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

(define-read-only (check-fak-vel-vel (pepe-in uint))
  (let (
    (sbtc-estimate (simulate-pepe-to-sbtc pepe-in))
    (stx-estimate (simulate-sbtc-to-stx-velar sbtc-estimate))
    (pepe-estimate (simulate-stx-to-pepe stx-estimate))
    (profit (if (> pepe-estimate pepe-in) (- pepe-estimate pepe-in) u0))
  )
  (ok {
    pepe-in: pepe-in,
    sbtc-out: sbtc-estimate,
    stx-out: stx-estimate,
    pepe-out: pepe-estimate,
    profit: profit,
    profitable: (> pepe-estimate pepe-in)
  }))
)

(define-read-only (check-vel-vel-fak (pepe-in uint))
  (let (
    (stx-estimate (simulate-pepe-to-stx pepe-in))
    (sbtc-estimate (simulate-stx-to-sbtc-velar stx-estimate))
    (pepe-estimate (simulate-sbtc-to-pepe sbtc-estimate))
    (profit (if (> pepe-estimate pepe-in) (- pepe-estimate pepe-in) u0))
  )
  (ok {
    pepe-in: pepe-in,
    stx-out: stx-estimate,
    sbtc-out: sbtc-estimate,
    pepe-out: pepe-estimate,
    profit: profit,
    profitable: (> pepe-estimate pepe-in)
  }))
)

;; ---- Bitflow PEPE-STX routes (xyk-pool-pepe-stx-v-1-1, PEPE=X, STX=Y) ----

;; STX -> PEPE: swap-y-for-x (send Y=STX, get X=PEPE)
(define-private (swap-stx-to-pepe-bitflow (stx-amount uint))
  (let (
      (dx (try! (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2
        swap-y-for-x
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-pepe-stx-v-1-1
        'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2
        stx-amount
        u1
      )))
    )
    (ok dx)
  )
)

;; PEPE -> STX: swap-x-for-y (send X=PEPE, get Y=STX)
(define-private (swap-pepe-to-stx-bitflow (pepe-amount uint))
  (let (
      (dy (try! (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2
        swap-x-for-y
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-pepe-stx-v-1-1
        'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2
        pepe-amount
        u1
      )))
    )
    (ok dy)
  )
)

;; PEPE -> sBTC (fakfun) -> STX (Bitflow) -> PEPE (Bitflow)
(define-public (arb-fak-bit-bit
    (pepe-in uint)
    (min-pepe-out uint))
  (begin
    (try! (contract-call?
      'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
      transfer
      pepe-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((sbtc-out (try! (as-contract (swap-pepe-to-sbtc pepe-in))))
          (stx-out (try! (as-contract (swap-sbtc-to-stx sbtc-out))))
          (pepe-out (try! (as-contract (swap-stx-to-pepe-bitflow stx-out)))))
          (asserts! (>= pepe-out min-pepe-out) ERR-SLIPPAGE)
          (asserts! (> pepe-out pepe-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
            transfer
            pepe-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: pepe-in,
            token-out: pepe-out
          })
        )
      )
    )

;; PEPE -> sBTC (fakfun) -> STX (Velar) -> PEPE (Bitflow)
(define-public (arb-fak-vel-bit
    (pepe-in uint)
    (min-pepe-out uint))
  (begin
    (try! (contract-call?
      'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
      transfer
      pepe-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((sbtc-out (try! (as-contract (swap-pepe-to-sbtc pepe-in))))
          (stx-out (try! (as-contract (swap-sbtc-to-stx-velar sbtc-out))))
          (pepe-out (try! (as-contract (swap-stx-to-pepe-bitflow stx-out)))))
          (asserts! (>= pepe-out min-pepe-out) ERR-SLIPPAGE)
          (asserts! (> pepe-out pepe-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
            transfer
            pepe-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: pepe-in,
            token-out: pepe-out
          })
        )
      )
    )

;; PEPE -> STX (Bitflow) -> sBTC (Bitflow) -> PEPE (fakfun)
(define-public (arb-bit-bit-fak
    (pepe-in uint)
    (min-pepe-out uint))
  (begin
    (try! (contract-call?
      'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
      transfer
      pepe-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((stx-out (try! (as-contract (swap-pepe-to-stx-bitflow pepe-in))))
          (sbtc-out (try! (as-contract (swap-stx-to-sbtc stx-out))))
          (pepe-out (try! (as-contract (swap-sbtc-to-pepe sbtc-out)))))
          (asserts! (>= pepe-out min-pepe-out) ERR-SLIPPAGE)
          (asserts! (> pepe-out pepe-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
            transfer
            pepe-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: pepe-in,
            token-out: pepe-out
          })
        )
      )
    )

;; PEPE -> STX (Bitflow) -> sBTC (Velar) -> PEPE (fakfun)
(define-public (arb-bit-vel-fak
    (pepe-in uint)
    (min-pepe-out uint))
  (begin
    (try! (contract-call?
      'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
      transfer
      pepe-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((stx-out (try! (as-contract (swap-pepe-to-stx-bitflow pepe-in))))
          (sbtc-out (try! (as-contract (swap-stx-to-sbtc-velar stx-out))))
          (pepe-out (try! (as-contract (swap-sbtc-to-pepe sbtc-out)))))
          (asserts! (>= pepe-out min-pepe-out) ERR-SLIPPAGE)
          (asserts! (> pepe-out pepe-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
            transfer
            pepe-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: pepe-in,
            token-out: pepe-out
          })
        )
      )
    )

;; Read-only (Bitflow PEPE-STX routes)
(define-read-only (check-fak-bit-bit (pepe-in uint))
  (let (
    (sbtc-estimate (simulate-pepe-to-sbtc pepe-in))
    (stx-estimate (simulate-sbtc-to-stx sbtc-estimate))
    (pepe-estimate (simulate-stx-to-pepe-bitflow stx-estimate))
    (profit (if (> pepe-estimate pepe-in) (- pepe-estimate pepe-in) u0))
  )
  (ok {
    pepe-in: pepe-in,
    sbtc-out: sbtc-estimate,
    stx-out: stx-estimate,
    pepe-out: pepe-estimate,
    profit: profit,
    profitable: (> pepe-estimate pepe-in)
  }))
)

(define-read-only (check-fak-vel-bit (pepe-in uint))
  (let (
    (sbtc-estimate (simulate-pepe-to-sbtc pepe-in))
    (stx-estimate (simulate-sbtc-to-stx-velar sbtc-estimate))
    (pepe-estimate (simulate-stx-to-pepe-bitflow stx-estimate))
    (profit (if (> pepe-estimate pepe-in) (- pepe-estimate pepe-in) u0))
  )
  (ok {
    pepe-in: pepe-in,
    sbtc-out: sbtc-estimate,
    stx-out: stx-estimate,
    pepe-out: pepe-estimate,
    profit: profit,
    profitable: (> pepe-estimate pepe-in)
  }))
)

(define-read-only (check-bit-bit-fak (pepe-in uint))
  (let (
    (stx-estimate (simulate-pepe-to-stx-bitflow pepe-in))
    (sbtc-estimate (simulate-stx-to-sbtc stx-estimate))
    (pepe-estimate (simulate-sbtc-to-pepe sbtc-estimate))
    (profit (if (> pepe-estimate pepe-in) (- pepe-estimate pepe-in) u0))
  )
  (ok {
    pepe-in: pepe-in,
    stx-out: stx-estimate,
    sbtc-out: sbtc-estimate,
    pepe-out: pepe-estimate,
    profit: profit,
    profitable: (> pepe-estimate pepe-in)
  }))
)

(define-read-only (check-bit-vel-fak (pepe-in uint))
  (let (
    (stx-estimate (simulate-pepe-to-stx-bitflow pepe-in))
    (sbtc-estimate (simulate-stx-to-sbtc-velar stx-estimate))
    (pepe-estimate (simulate-sbtc-to-pepe sbtc-estimate))
    (profit (if (> pepe-estimate pepe-in) (- pepe-estimate pepe-in) u0))
  )
  (ok {
    pepe-in: pepe-in,
    stx-out: stx-estimate,
    sbtc-out: sbtc-estimate,
    pepe-out: pepe-estimate,
    profit: profit,
    profitable: (> pepe-estimate pepe-in)
  }))
)

;; Bitflow PEPE-STX: PEPE=X, STX=Y. swap-y-for-x: get X=PEPE out
(define-read-only (simulate-stx-to-pepe-bitflow (stx-amount uint))
  (let (
      (pool (unwrap-panic (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-pepe-stx-v-1-1
        get-pool
      )))
      (x-balance (get x-balance pool))  ;; PEPE
      (y-balance (get y-balance pool))  ;; STX
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

;; Bitflow PEPE-STX: PEPE=X, STX=Y. swap-x-for-y: get Y=STX out
(define-read-only (simulate-pepe-to-stx-bitflow (pepe-amount uint))
  (let (
      (pool (unwrap-panic (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-pepe-stx-v-1-1
        get-pool
      )))
      (x-balance (get x-balance pool))  ;; PEPE
      (y-balance (get y-balance pool))  ;; STX
      (protocol-fee (get x-protocol-fee pool))
      (provider-fee (get x-provider-fee pool))
      (BPS u10000)
      (x-amount-fees-protocol (/ (* pepe-amount protocol-fee) BPS))
      (x-amount-fees-provider (/ (* pepe-amount provider-fee) BPS))
      (x-amount-fees-total (+ x-amount-fees-protocol x-amount-fees-provider))
      (dx (- pepe-amount x-amount-fees-total))
      (updated-x-balance (+ x-balance dx))
      (dy (/ (* y-balance dx) updated-x-balance))
    )
    dy
  )
)