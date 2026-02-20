;; Arbitrage v2: FLAT -> sBTC -> STX -> FLAT
;; Routes through fakfun-core-v2 (emits DB events)
;; Keeps profits (no SAINT burn)
;; Bitflow STX-FLAT pool is REVERSED: STX=X, FLAT=Y
;; Velar FLAT-STX is direct pool 0003

(define-constant ERR-SLIPPAGE (err u1000))
(define-constant ERR-NO-PROFIT (err u1001))

(define-constant DEPLOYER tx-sender)
(define-constant CONTRACT (as-contract tx-sender))

(define-public (arb-fak-bit-bit
    (flat-in uint)
    (min-flat-out uint))
  (begin
    (try! (contract-call?
      'SP3W69VDG9VTZNG7NTW1QNCC1W45SNY98W1JSZBJH.flat-earth-stxcity
      transfer
      flat-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((sbtc-out (try! (as-contract (swap-flat-to-sbtc flat-in))))
          (stx-out (try! (as-contract (swap-sbtc-to-stx sbtc-out))))
          (flat-out (try! (as-contract (swap-stx-to-flat-bitflow stx-out)))))

          (asserts! (>= flat-out min-flat-out) ERR-SLIPPAGE)
          (asserts! (> flat-out flat-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP3W69VDG9VTZNG7NTW1QNCC1W45SNY98W1JSZBJH.flat-earth-stxcity
            transfer
            flat-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: flat-in,
            token-out: flat-out
          })
        )
      )
    )

(define-private (swap-flat-to-sbtc (flat-amount uint))
  (let (
      (result (try! (contract-call?
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-core-v2
        execute
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.flatearth-faktory-pool-v2
        flat-amount
        (some 0x01)
      )))
    )
    ;; B-to-A: pool returns raw dy, FAKTORY_FEE (1/1000) skimmed from sBTC output
    (ok (/ (* (get dy result) u999) u1000))
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

;; Bitflow STX-FLAT (REVERSED: STX=X, FLAT=Y)
;; STX -> FLAT: swap-x-for-y (sending X=STX, getting Y=FLAT)
(define-private (swap-stx-to-flat-bitflow (stx-amount uint))
  (let (
      (dy (try! (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2
        swap-x-for-y
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-flat-v-1-1
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2
        'SP3W69VDG9VTZNG7NTW1QNCC1W45SNY98W1JSZBJH.flat-earth-stxcity
        stx-amount
        u1
      )))
    )
    (ok dy)
  )
)

(define-public (arb-fak-vel-vel
    (flat-in uint)
    (min-flat-out uint))
  (begin
    (try! (contract-call?
      'SP3W69VDG9VTZNG7NTW1QNCC1W45SNY98W1JSZBJH.flat-earth-stxcity
      transfer
      flat-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((sbtc-out (try! (as-contract (swap-flat-to-sbtc flat-in))))
          (stx-out (try! (as-contract (swap-sbtc-to-stx-velar sbtc-out))))
          (flat-out (try! (as-contract (swap-stx-to-flat-velar stx-out)))))

          (asserts! (>= flat-out min-flat-out) ERR-SLIPPAGE)
          (asserts! (> flat-out flat-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP3W69VDG9VTZNG7NTW1QNCC1W45SNY98W1JSZBJH.flat-earth-stxcity
            transfer
            flat-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: flat-in,
            token-out: flat-out
          })
        )
      )
    )

;; REVEEEEEERSE
(define-public (arb-bit-bit-fak
    (flat-in uint)
    (min-flat-out uint))
  (begin
    (try! (contract-call?
      'SP3W69VDG9VTZNG7NTW1QNCC1W45SNY98W1JSZBJH.flat-earth-stxcity
      transfer
      flat-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((stx-out (try! (as-contract (swap-flat-to-stx-bitflow flat-in))))
          (sbtc-out (try! (as-contract (swap-stx-to-sbtc stx-out))))
          (flat-out (try! (as-contract (swap-sbtc-to-flat sbtc-out)))))

          (asserts! (>= flat-out min-flat-out) ERR-SLIPPAGE)
          (asserts! (> flat-out flat-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP3W69VDG9VTZNG7NTW1QNCC1W45SNY98W1JSZBJH.flat-earth-stxcity
            transfer
            flat-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: flat-in,
            token-out: flat-out
          })
        )
      )
    )

;; Bitflow STX-FLAT (REVERSED: STX=X, FLAT=Y)
;; FLAT -> STX: swap-y-for-x (sending Y=FLAT, getting X=STX)
(define-private (swap-flat-to-stx-bitflow (flat-amount uint))
  (let (
      (dx (try! (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2
        swap-y-for-x
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-flat-v-1-1
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2
        'SP3W69VDG9VTZNG7NTW1QNCC1W45SNY98W1JSZBJH.flat-earth-stxcity
        flat-amount
        u1
      )))
    )
    (ok dx)
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

(define-private (swap-sbtc-to-flat (sbtc-amount uint))
  (let (
      (result (try! (contract-call?
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-core-v2
        execute
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.flatearth-faktory-pool-v2
        sbtc-amount
        (some 0x00)
      )))
    )
    (ok (get dy result))
  )
)

(define-public (arb-vel-vel-fak
    (flat-in uint)
    (min-flat-out uint))
  (begin
    (try! (contract-call?
      'SP3W69VDG9VTZNG7NTW1QNCC1W45SNY98W1JSZBJH.flat-earth-stxcity
      transfer
      flat-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((stx-out (try! (as-contract (swap-flat-to-stx-velar flat-in))))
          (sbtc-out (try! (as-contract (swap-stx-to-sbtc-velar stx-out))))
          (flat-out (try! (as-contract (swap-sbtc-to-flat sbtc-out)))))

          (asserts! (>= flat-out min-flat-out) ERR-SLIPPAGE)
          (asserts! (> flat-out flat-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP3W69VDG9VTZNG7NTW1QNCC1W45SNY98W1JSZBJH.flat-earth-stxcity
            transfer
            flat-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: flat-in,
            token-out: flat-out
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

(define-private (swap-stx-to-flat-velar (stx-amount uint))
  (let (
      (result (try! (contract-call?
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-pool-v1_0_0-0003
        swap
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx
        'SP3W69VDG9VTZNG7NTW1QNCC1W45SNY98W1JSZBJH.flat-earth-stxcity
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-fees-v1_0_0-0003
        stx-amount
        u1
      )))
    )
    (ok (get amt-out result))
  )
)

(define-private (swap-flat-to-stx-velar (flat-amount uint))
  (let (
      (result (try! (contract-call?
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-pool-v1_0_0-0003
        swap
        'SP3W69VDG9VTZNG7NTW1QNCC1W45SNY98W1JSZBJH.flat-earth-stxcity
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-fees-v1_0_0-0003
        flat-amount
        u1
      )))
    )
    (ok (get amt-out result))
  )
)

;; Read-only
(define-read-only (check-fak-bit-bit (flat-in uint))
  (let (
    (sbtc-estimate (simulate-flat-to-sbtc flat-in))
    (stx-estimate (simulate-sbtc-to-stx sbtc-estimate))
    (flat-estimate (simulate-stx-to-flat-bitflow stx-estimate))
    (profit (if (> flat-estimate flat-in) (- flat-estimate flat-in) u0))
  )
  (ok {
    flat-in: flat-in,
    sbtc-out: sbtc-estimate,
    stx-out: stx-estimate,
    flat-out: flat-estimate,
    profit: profit,
    profitable: (> flat-estimate flat-in)
  }))
)

(define-read-only (check-bit-bit-fak (flat-in uint))
  (let (
    (stx-estimate (simulate-flat-to-stx-bitflow flat-in))
    (sbtc-estimate (simulate-stx-to-sbtc stx-estimate))
    (flat-estimate (simulate-sbtc-to-flat sbtc-estimate))
    (profit (if (> flat-estimate flat-in) (- flat-estimate flat-in) u0))
  )
  (ok {
    flat-in: flat-in,
    stx-out: stx-estimate,
    sbtc-out: sbtc-estimate,
    flat-out: flat-estimate,
    profit: profit,
    profitable: (> flat-estimate flat-in)
  }))
)

(define-read-only (simulate-flat-to-sbtc (flat-amount uint))
  ;; Protocol fee: 1/1000 skimmed from sBTC output
  (/ (* (get dy (unwrap-panic (contract-call?
    'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.flatearth-faktory-pool-v2
    quote
    flat-amount
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

;; Bitflow STX-FLAT simulation (REVERSED: STX=X, FLAT=Y)
;; STX -> FLAT: swap-x-for-y (send X=STX, get Y=FLAT)
(define-read-only (simulate-stx-to-flat-bitflow (stx-amount uint))
  (let (
      (pool (unwrap-panic (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-flat-v-1-1
        get-pool
      )))
      (x-balance (get x-balance pool))  ;; STX
      (y-balance (get y-balance pool))  ;; FLAT
      (protocol-fee (get x-protocol-fee pool))
      (provider-fee (get x-provider-fee pool))
      (BPS u10000)
      (x-amount-fees-protocol (/ (* stx-amount protocol-fee) BPS))
      (x-amount-fees-provider (/ (* stx-amount provider-fee) BPS))
      (x-amount-fees-total (+ x-amount-fees-protocol x-amount-fees-provider))
      (dx (- stx-amount x-amount-fees-total))
      (updated-x-balance (+ x-balance dx))
      (dy (/ (* y-balance dx) updated-x-balance))
    )
    dy
  )
)

;; FLAT -> STX: swap-y-for-x (send Y=FLAT, get X=STX)
(define-read-only (simulate-flat-to-stx-bitflow (flat-amount uint))
  (let (
      (pool (unwrap-panic (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-flat-v-1-1
        get-pool
      )))
      (x-balance (get x-balance pool))  ;; STX
      (y-balance (get y-balance pool))  ;; FLAT
      (protocol-fee (get y-protocol-fee pool))
      (provider-fee (get y-provider-fee pool))
      (BPS u10000)
      (y-amount-fees-protocol (/ (* flat-amount protocol-fee) BPS))
      (y-amount-fees-provider (/ (* flat-amount provider-fee) BPS))
      (y-amount-fees-total (+ y-amount-fees-protocol y-amount-fees-provider))
      (dy (- flat-amount y-amount-fees-total))
      (updated-y-balance (+ y-balance dy))
      (dx (/ (* x-balance dy) updated-y-balance))
    )
    dx
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

(define-read-only (simulate-sbtc-to-flat (sbtc-amount uint))
  ;; A-to-B: quote already nets FAKTORY_FEE from sBTC input
  (get dy (unwrap-panic (contract-call?
    'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.flatearth-faktory-pool-v2
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

;; Velar FLAT-STX simulation (direct pool 0003)
(define-read-only (simulate-stx-to-flat-velar (stx-amount uint))
  (let ((pool (unwrap-panic (contract-call?
          'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-pool-v1_0_0-0003
          get-pool)))
        (r0 (get reserve0 pool))
        (r1 (get reserve1 pool))
        (amt-in-adjusted (/ (* stx-amount u997) u1000))
        (amt-out (/ (* r0 amt-in-adjusted) (+ r1 amt-in-adjusted)))
  )
  amt-out)
)

(define-read-only (simulate-flat-to-stx-velar (flat-amount uint))
  (let ((pool (unwrap-panic (contract-call?
          'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-pool-v1_0_0-0003
          get-pool)))
        (r0 (get reserve0 pool))
        (r1 (get reserve1 pool))
        (amt-in-adjusted (/ (* flat-amount u997) u1000))
        (amt-out (/ (* r1 amt-in-adjusted) (+ r0 amt-in-adjusted)))
  )
  amt-out)
)

(define-read-only (check-fak-vel-vel (flat-in uint))
  (let (
    (sbtc-estimate (simulate-flat-to-sbtc flat-in))
    (stx-estimate (simulate-sbtc-to-stx-velar sbtc-estimate))
    (flat-estimate (simulate-stx-to-flat-velar stx-estimate))
    (profit (if (> flat-estimate flat-in) (- flat-estimate flat-in) u0))
  )
  (ok {
    flat-in: flat-in,
    sbtc-out: sbtc-estimate,
    stx-out: stx-estimate,
    flat-out: flat-estimate,
    profit: profit,
    profitable: (> flat-estimate flat-in)
  }))
)

(define-read-only (check-vel-vel-fak (flat-in uint))
  (let (
    (stx-estimate (simulate-flat-to-stx-velar flat-in))
    (sbtc-estimate (simulate-stx-to-sbtc-velar stx-estimate))
    (flat-estimate (simulate-sbtc-to-flat sbtc-estimate))
    (profit (if (> flat-estimate flat-in) (- flat-estimate flat-in) u0))
  )
  (ok {
    flat-in: flat-in,
    stx-out: stx-estimate,
    sbtc-out: sbtc-estimate,
    flat-out: flat-estimate,
    profit: profit,
    profitable: (> flat-estimate flat-in)
  }))
)