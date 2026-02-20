;; Arbitrage v2: NASTY -> sBTC -> STX -> NASTY
;; Routes through fakfun-core-v2 (emits DB events)
;; Keeps profits (no SAINT burn)

(define-constant ERR-SLIPPAGE (err u1000))
(define-constant ERR-NO-PROFIT (err u1001))

(define-constant DEPLOYER tx-sender)
(define-constant CONTRACT (as-contract tx-sender))

(define-public (arb-fak-bit-bit
    (nasty-in uint)
    (min-nasty-out uint))
  (begin
    (try! (contract-call?
      'SP2TT71CXBRDDYP2P8XMVKRFYKRGSMBWCZ6W6FDGT.notastrategy
      transfer
      nasty-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((sbtc-out (try! (as-contract (swap-nasty-to-sbtc nasty-in))))
          (stx-out (try! (as-contract (swap-sbtc-to-stx sbtc-out))))
          (nasty-out (try! (as-contract (swap-stx-to-nasty stx-out)))))

          (asserts! (>= nasty-out min-nasty-out) ERR-SLIPPAGE)
          (asserts! (> nasty-out nasty-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP2TT71CXBRDDYP2P8XMVKRFYKRGSMBWCZ6W6FDGT.notastrategy
            transfer
            nasty-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: nasty-in,
            token-out: nasty-out
          })
        )
      )
    )

(define-private (swap-nasty-to-sbtc (nasty-amount uint))
  (let (
      (result (try! (contract-call?
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-core-v2
        execute
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.nasty-faktory-pool-v2
        nasty-amount
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

(define-private (swap-stx-to-nasty (stx-amount uint))
  (let (
      (dx (try! (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2
        swap-y-for-x
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-nasty-stx-v-1-1
        'SP2TT71CXBRDDYP2P8XMVKRFYKRGSMBWCZ6W6FDGT.notastrategy
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2
        stx-amount
        u1
      )))
    )
    (ok dx)
  )
)

(define-public (arb-fak-vel-bit
    (nasty-in uint)
    (min-nasty-out uint))
  (begin
    (try! (contract-call?
      'SP2TT71CXBRDDYP2P8XMVKRFYKRGSMBWCZ6W6FDGT.notastrategy
      transfer
      nasty-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((sbtc-out (try! (as-contract (swap-nasty-to-sbtc nasty-in))))
          (stx-out (try! (as-contract (swap-sbtc-to-stx-velar sbtc-out))))
          (nasty-out (try! (as-contract (swap-stx-to-nasty stx-out)))))

          (asserts! (>= nasty-out min-nasty-out) ERR-SLIPPAGE)
          (asserts! (> nasty-out nasty-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP2TT71CXBRDDYP2P8XMVKRFYKRGSMBWCZ6W6FDGT.notastrategy
            transfer
            nasty-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: nasty-in,
            token-out: nasty-out
          })
        )
      )
    )

;; REVEEEEEERSE
(define-public (arb-bit-bit-fak
    (nasty-in uint)
    (min-nasty-out uint))
  (begin
    (try! (contract-call?
      'SP2TT71CXBRDDYP2P8XMVKRFYKRGSMBWCZ6W6FDGT.notastrategy
      transfer
      nasty-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((stx-out (try! (as-contract (swap-nasty-to-stx nasty-in))))
          (sbtc-out (try! (as-contract (swap-stx-to-sbtc stx-out))))
          (nasty-out (try! (as-contract (swap-sbtc-to-nasty sbtc-out)))))

          (asserts! (>= nasty-out min-nasty-out) ERR-SLIPPAGE)
          (asserts! (> nasty-out nasty-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP2TT71CXBRDDYP2P8XMVKRFYKRGSMBWCZ6W6FDGT.notastrategy
            transfer
            nasty-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: nasty-in,
            token-out: nasty-out
          })
        )
      )
    )

(define-private (swap-nasty-to-stx (nasty-amount uint))
  (let (
      (dy (try! (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2
        swap-x-for-y
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-nasty-stx-v-1-1
        'SP2TT71CXBRDDYP2P8XMVKRFYKRGSMBWCZ6W6FDGT.notastrategy
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2
        nasty-amount
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

(define-private (swap-sbtc-to-nasty (sbtc-amount uint))
  (let (
      (result (try! (contract-call?
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-core-v2
        execute
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.nasty-faktory-pool-v2
        sbtc-amount
        (some 0x00)
      )))
    )
    (ok (get dy result))
  )
)

(define-public (arb-bit-vel-fak
    (nasty-in uint)
    (min-nasty-out uint))
  (begin
    (try! (contract-call?
      'SP2TT71CXBRDDYP2P8XMVKRFYKRGSMBWCZ6W6FDGT.notastrategy
      transfer
      nasty-in
      tx-sender
      CONTRACT
      none
    ))
    (let ((stx-out (try! (as-contract (swap-nasty-to-stx nasty-in))))
          (sbtc-out (try! (as-contract (swap-stx-to-sbtc-velar stx-out))))
          (nasty-out (try! (as-contract (swap-sbtc-to-nasty sbtc-out)))))

          (asserts! (>= nasty-out min-nasty-out) ERR-SLIPPAGE)
          (asserts! (> nasty-out nasty-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call?
            'SP2TT71CXBRDDYP2P8XMVKRFYKRGSMBWCZ6W6FDGT.notastrategy
            transfer
            nasty-out
            CONTRACT
            DEPLOYER
            none
          )))
          (ok {
            token-in: nasty-in,
            token-out: nasty-out
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
(define-read-only (check-fak-bit-bit (nasty-in uint))
  (let (
    (sbtc-estimate (simulate-nasty-to-sbtc nasty-in))
    (stx-estimate (simulate-sbtc-to-stx sbtc-estimate))
    (nasty-estimate (simulate-stx-to-nasty stx-estimate))
    (profit (if (> nasty-estimate nasty-in) (- nasty-estimate nasty-in) u0))
  )
  (ok {
    nasty-in: nasty-in,
    sbtc-out: sbtc-estimate,
    stx-out: stx-estimate,
    nasty-out: nasty-estimate,
    profit: profit,
    profitable: (> nasty-estimate nasty-in)
  }))
)

(define-read-only (check-bit-bit-fak (nasty-in uint))
  (let (
    (stx-estimate (simulate-nasty-to-stx nasty-in))
    (sbtc-estimate (simulate-stx-to-sbtc stx-estimate))
    (nasty-estimate (simulate-sbtc-to-nasty sbtc-estimate))
    (profit (if (> nasty-estimate nasty-in) (- nasty-estimate nasty-in) u0))
  )
  (ok {
    nasty-in: nasty-in,
    stx-out: stx-estimate,
    sbtc-out: sbtc-estimate,
    nasty-out: nasty-estimate,
    profit: profit,
    profitable: (> nasty-estimate nasty-in)
  }))
)

(define-read-only (simulate-nasty-to-sbtc (nasty-amount uint))
  (get dy (unwrap-panic (contract-call?
    'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.nasty-faktory-pool-v2
    quote
    nasty-amount
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

(define-read-only (simulate-stx-to-nasty (stx-amount uint))
  ;; Bitflow NASTY-STX: NASTY=X, STX=Y. swap-y-for-x: get X=NASTY out
  (let (
      (pool (unwrap-panic (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-nasty-stx-v-1-1
        get-pool
      )))
      (x-balance (get x-balance pool))  ;; NASTY
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

(define-read-only (simulate-nasty-to-stx (nasty-amount uint))
  ;; Bitflow NASTY-STX: NASTY=X, STX=Y. swap-x-for-y: get Y=STX out
  (let (
      (pool (unwrap-panic (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-nasty-stx-v-1-1
        get-pool
      )))
      (x-balance (get x-balance pool))  ;; NASTY
      (y-balance (get y-balance pool))  ;; STX
      (protocol-fee (get x-protocol-fee pool))
      (provider-fee (get x-provider-fee pool))
      (BPS u10000)
      (x-amount-fees-protocol (/ (* nasty-amount protocol-fee) BPS))
      (x-amount-fees-provider (/ (* nasty-amount provider-fee) BPS))
      (x-amount-fees-total (+ x-amount-fees-protocol x-amount-fees-provider))
      (dx (- nasty-amount x-amount-fees-total))
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

(define-read-only (simulate-sbtc-to-nasty (sbtc-amount uint))
  (get dy (unwrap-panic (contract-call?
    'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.nasty-faktory-pool-v2
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

(define-read-only (check-fak-vel-bit (nasty-in uint))
  (let (
    (sbtc-estimate (simulate-nasty-to-sbtc nasty-in))
    (stx-estimate (simulate-sbtc-to-stx-velar sbtc-estimate))
    (nasty-estimate (simulate-stx-to-nasty stx-estimate))
    (profit (if (> nasty-estimate nasty-in) (- nasty-estimate nasty-in) u0))
  )
  (ok {
    nasty-in: nasty-in,
    sbtc-out: sbtc-estimate,
    stx-out: stx-estimate,
    nasty-out: nasty-estimate,
    profit: profit,
    profitable: (> nasty-estimate nasty-in)
  }))
)

(define-read-only (check-bit-vel-fak (nasty-in uint))
  (let (
    (stx-estimate (simulate-nasty-to-stx nasty-in))
    (sbtc-estimate (simulate-stx-to-sbtc-velar stx-estimate))
    (nasty-estimate (simulate-sbtc-to-nasty sbtc-estimate))
    (profit (if (> nasty-estimate nasty-in) (- nasty-estimate nasty-in) u0))
  )
  (ok {
    nasty-in: nasty-in,
    stx-out: stx-estimate,
    sbtc-out: sbtc-estimate,
    nasty-out: nasty-estimate,
    profit: profit,
    profitable: (> nasty-estimate nasty-in)
  }))
)
