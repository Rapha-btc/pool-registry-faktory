;; Arbitrage v2: POS -> sBTC -> STX -> POS
;; Routes through fakfun-core-v2 (emits DB events)
;; Keeps profits (no SAINT burn)

(define-constant ERR-SLIPPAGE (err u1000))
(define-constant ERR-NO-PROFIT (err u1001))

(define-constant DEPLOYER tx-sender)
(define-constant CONTRACT (as-contract tx-sender))

(define-public (arb-fak-bit-vel
    (pos-in uint)
    (min-pos-out uint))
  (begin
    (try! (contract-call?
      'SPGNH14RQWAT05PVG8CEXCM7BGC5PPR01XVGQXPZ.pos-coin-stxcity
      transfer
      pos-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((sbtc-out (try! (as-contract (swap-pos-to-sbtc pos-in))))
          (stx-out (try! (as-contract (swap-sbtc-to-stx sbtc-out))))
          (pos-out (try! (as-contract (swap-stx-to-pos stx-out)))))

          (asserts! (>= pos-out min-pos-out) ERR-SLIPPAGE)
          (asserts! (> pos-out pos-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SPGNH14RQWAT05PVG8CEXCM7BGC5PPR01XVGQXPZ.pos-coin-stxcity
            transfer
            pos-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: pos-in,
            token-out: pos-out
          })
        )
      )
    )

(define-private (swap-pos-to-sbtc (pos-amount uint))
  (let (
      (result (try! (contract-call?
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-core-v2
        execute
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.pos-faktory-pool-v2
        pos-amount
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

(define-private (swap-stx-to-pos (stx-amount uint))
  (let (
      (result (try! (contract-call?
        'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0143
        swap
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx
        'SPGNH14RQWAT05PVG8CEXCM7BGC5PPR01XVGQXPZ.pos-coin-stxcity
        'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-fees-v1_0_0-0143
        stx-amount
        u1
      )))
    )
    (ok (get amt-out result))
  )
)

(define-public (arb-fak-vel-vel
    (pos-in uint)
    (min-pos-out uint))
  (begin
    (try! (contract-call?
      'SPGNH14RQWAT05PVG8CEXCM7BGC5PPR01XVGQXPZ.pos-coin-stxcity
      transfer
      pos-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((sbtc-out (try! (as-contract (swap-pos-to-sbtc pos-in))))
          (stx-out (try! (as-contract (swap-sbtc-to-stx-velar sbtc-out))))
          (pos-out (try! (as-contract (swap-stx-to-pos stx-out)))))

          (asserts! (>= pos-out min-pos-out) ERR-SLIPPAGE)
          (asserts! (> pos-out pos-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SPGNH14RQWAT05PVG8CEXCM7BGC5PPR01XVGQXPZ.pos-coin-stxcity
            transfer
            pos-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: pos-in,
            token-out: pos-out
          })
        )
      )
    )

;; REVEEEEEERSE
(define-public (arb-vel-bit-fak
    (pos-in uint)
    (min-pos-out uint))
  (begin
    (try! (contract-call?
      'SPGNH14RQWAT05PVG8CEXCM7BGC5PPR01XVGQXPZ.pos-coin-stxcity
      transfer
      pos-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((stx-out (try! (as-contract (swap-pos-to-stx pos-in))))
          (sbtc-out (try! (as-contract (swap-stx-to-sbtc stx-out))))
          (pos-out (try! (as-contract (swap-sbtc-to-pos sbtc-out)))))

          (asserts! (>= pos-out min-pos-out) ERR-SLIPPAGE)
          (asserts! (> pos-out pos-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SPGNH14RQWAT05PVG8CEXCM7BGC5PPR01XVGQXPZ.pos-coin-stxcity
            transfer
            pos-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: pos-in,
            token-out: pos-out
          })
        )
      )
    )

(define-private (swap-pos-to-stx (pos-amount uint))
  (let (
      (result (try! (contract-call?
        'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0143
        swap
        'SPGNH14RQWAT05PVG8CEXCM7BGC5PPR01XVGQXPZ.pos-coin-stxcity
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx
        'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-fees-v1_0_0-0143
        pos-amount
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

(define-private (swap-sbtc-to-pos (sbtc-amount uint))
  (let (
      (result (try! (contract-call?
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-core-v2
        execute
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.pos-faktory-pool-v2
        sbtc-amount
        (some 0x00)
      )))
    )
    (ok (get dy result))
  )
)

(define-public (arb-vel-vel-fak
    (pos-in uint)
    (min-pos-out uint))
  (begin
    (try! (contract-call?
      'SPGNH14RQWAT05PVG8CEXCM7BGC5PPR01XVGQXPZ.pos-coin-stxcity
      transfer
      pos-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((stx-out (try! (as-contract (swap-pos-to-stx pos-in))))
          (sbtc-out (try! (as-contract (swap-stx-to-sbtc-velar stx-out))))
          (pos-out (try! (as-contract (swap-sbtc-to-pos sbtc-out)))))

          (asserts! (>= pos-out min-pos-out) ERR-SLIPPAGE)
          (asserts! (> pos-out pos-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SPGNH14RQWAT05PVG8CEXCM7BGC5PPR01XVGQXPZ.pos-coin-stxcity
            transfer
            pos-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: pos-in,
            token-out: pos-out
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
(define-read-only (check-fak-bit-vel (pos-in uint))
  (let (
    (sbtc-estimate (simulate-pos-to-sbtc pos-in))
    (stx-estimate (simulate-sbtc-to-stx sbtc-estimate))
    (pos-estimate (simulate-stx-to-pos stx-estimate))
    (profit (if (> pos-estimate pos-in) (- pos-estimate pos-in) u0))
  )
  (ok {
    pos-in: pos-in,
    sbtc-out: sbtc-estimate,
    stx-out: stx-estimate,
    pos-out: pos-estimate,
    profit: profit,
    profitable: (> pos-estimate pos-in)
  }))
)

(define-read-only (check-vel-bit-fak (pos-in uint))
  (let (
    (stx-estimate (simulate-pos-to-stx pos-in))
    (sbtc-estimate (simulate-stx-to-sbtc stx-estimate))
    (pos-estimate (simulate-sbtc-to-pos sbtc-estimate))
    (profit (if (> pos-estimate pos-in) (- pos-estimate pos-in) u0))
  )
  (ok {
    pos-in: pos-in,
    stx-out: stx-estimate,
    sbtc-out: sbtc-estimate,
    pos-out: pos-estimate,
    profit: profit,
    profitable: (> pos-estimate pos-in)
  }))
)

(define-read-only (simulate-pos-to-sbtc (pos-amount uint))
  ;; Protocol fee: 1/1000 skimmed from sBTC output
  (/ (* (get dy (unwrap-panic (contract-call?
    'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.pos-faktory-pool-v2
    quote
    pos-amount
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

(define-read-only (simulate-stx-to-pos (stx-amount uint))
  (let ((pool (unwrap-panic (contract-call?
          'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0143
          get-pool)))
        (r0 (get reserve0 pool)) ;; STX (or wSTX)
        (r1 (get reserve1 pool)) ;; POS
        (amt-in-adjusted (/ (* stx-amount u997) u1000))
        (amt-out (/ (* r1 amt-in-adjusted) (+ r0 amt-in-adjusted)))
  )
  amt-out)
)

(define-read-only (simulate-pos-to-stx (pos-amount uint))
  (let ((pool (unwrap-panic (contract-call?
          'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0143
          get-pool)))
        (r0 (get reserve0 pool)) ;; STX
        (r1 (get reserve1 pool)) ;; POS
        (amt-in-adjusted (/ (* pos-amount u997) u1000))
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

(define-read-only (simulate-sbtc-to-pos (sbtc-amount uint))
  ;; A-to-B: quote already nets FAKTORY_FEE from sBTC input
  (get dy (unwrap-panic (contract-call?
    'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.pos-faktory-pool-v2
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

(define-read-only (check-fak-vel-vel (pos-in uint))
  (let (
    (sbtc-estimate (simulate-pos-to-sbtc pos-in))
    (stx-estimate (simulate-sbtc-to-stx-velar sbtc-estimate))
    (pos-estimate (simulate-stx-to-pos stx-estimate))
    (profit (if (> pos-estimate pos-in) (- pos-estimate pos-in) u0))
  )
  (ok {
    pos-in: pos-in,
    sbtc-out: sbtc-estimate,
    stx-out: stx-estimate,
    pos-out: pos-estimate,
    profit: profit,
    profitable: (> pos-estimate pos-in)
  }))
)

(define-read-only (check-vel-vel-fak (pos-in uint))
  (let (
    (stx-estimate (simulate-pos-to-stx pos-in))
    (sbtc-estimate (simulate-stx-to-sbtc-velar stx-estimate))
    (pos-estimate (simulate-sbtc-to-pos sbtc-estimate))
    (profit (if (> pos-estimate pos-in) (- pos-estimate pos-in) u0))
  )
  (ok {
    pos-in: pos-in,
    stx-out: stx-estimate,
    sbtc-out: sbtc-estimate,
    pos-out: pos-estimate,
    profit: profit,
    profitable: (> pos-estimate pos-in)
  }))
)
