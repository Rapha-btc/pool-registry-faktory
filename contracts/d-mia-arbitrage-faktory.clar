(define-constant ERR-SLIPPAGE (err u1000))
(define-constant ERR-NO-PROFIT (err u1001))
(define-constant ERR-NOT-AUTHORIZED (err u1002))
(define-constant ERR-PARTIAL-FILL (err u1003))

(define-constant DEPLOYER tx-sender)

(define-public (arb-fak-bit-alex
    (amt-in uint)
    (min-amt-out uint)
  )
  (begin
    (try! (contract-call? 'SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token-v2
      transfer amt-in tx-sender current-contract none
    ))
    (let (
        (sbtc-out (try! (as-contract?
          ((with-ft 'SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token-v2
            "miamicoin" amt-in
          ))
          (try! (swap-token-to-sbtc amt-in))
        )))
        (stx-out (try! (as-contract?
          ((with-ft 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
            "sbtc-token" sbtc-out
          ))
          (try! (swap-sbtc-to-stx sbtc-out))
        )))
        (amt-out (try! (as-contract? ((with-stx stx-out))
          (try! (swap-stx-to-token-alex stx-out))
        )))
      )
      (asserts! (>= amt-out min-amt-out) ERR-SLIPPAGE)
      (asserts! (> amt-out amt-in) ERR-NO-PROFIT)
      (try! (pay-deployer amt-out))
      (ok {
        token-in: amt-in,
        token-out: amt-out,
      })
    )
  )
)

(define-public (arb-fak-vel-alex
    (amt-in uint)
    (min-amt-out uint)
  )
  (begin
    (try! (contract-call? 'SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token-v2
      transfer amt-in tx-sender current-contract none
    ))
    (let (
        (sbtc-out (try! (as-contract?
          ((with-ft 'SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token-v2
            "miamicoin" amt-in
          ))
          (try! (swap-token-to-sbtc amt-in))
        )))
        (stx-out (try! (as-contract?
          ((with-ft 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
            "sbtc-token" sbtc-out
          ))
          (try! (swap-sbtc-to-stx-velar sbtc-out))
        )))
        (amt-out (try! (as-contract? ((with-stx stx-out))
          (try! (swap-stx-to-token-alex stx-out))
        )))
      )
      (asserts! (>= amt-out min-amt-out) ERR-SLIPPAGE)
      (asserts! (> amt-out amt-in) ERR-NO-PROFIT)
      (try! (pay-deployer amt-out))
      (ok {
        token-in: amt-in,
        token-out: amt-out,
      })
    )
  )
)

(define-public (arb-fak-dlmm-alex
    (amt-in uint)
    (min-amt-out uint)
    (dlmm-pool uint)
  )
  (begin
    (try! (contract-call? 'SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token-v2
      transfer amt-in tx-sender current-contract none
    ))
    (let (
        (sbtc-out (try! (as-contract?
          ((with-ft 'SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token-v2
            "miamicoin" amt-in
          ))
          (try! (swap-token-to-sbtc amt-in))
        )))
        (stx-out (try! (as-contract?
          ((with-ft 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
            "sbtc-token" sbtc-out
          ))
          (try! (swap-sbtc-to-stx-dlmm dlmm-pool sbtc-out))
        )))
        (amt-out (try! (as-contract? ((with-stx stx-out))
          (try! (swap-stx-to-token-alex stx-out))
        )))
      )
      (asserts! (>= amt-out min-amt-out) ERR-SLIPPAGE)
      (asserts! (> amt-out amt-in) ERR-NO-PROFIT)
      (try! (pay-deployer amt-out))
      (ok {
        token-in: amt-in,
        token-out: amt-out,
      })
    )
  )
)

(define-public (arb-alex-bit-fak
    (amt-in uint)
    (min-amt-out uint)
  )
  (begin
    (try! (contract-call? 'SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token-v2
      transfer amt-in tx-sender current-contract none
    ))
    (let (
        (stx-out (try! (as-contract?
          ((with-ft 'SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token-v2
            "miamicoin" amt-in
          ))
          (try! (swap-token-to-stx-alex amt-in))
        )))
        (sbtc-out (try! (as-contract? ((with-stx stx-out)) (try! (swap-stx-to-sbtc stx-out)))))
        (amt-out (try! (as-contract?
          ((with-ft 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
            "sbtc-token" sbtc-out
          ))
          (try! (swap-sbtc-to-token sbtc-out))
        )))
      )
      (asserts! (>= amt-out min-amt-out) ERR-SLIPPAGE)
      (asserts! (> amt-out amt-in) ERR-NO-PROFIT)
      (try! (pay-deployer amt-out))
      (ok {
        token-in: amt-in,
        token-out: amt-out,
      })
    )
  )
)

(define-public (arb-alex-vel-fak
    (amt-in uint)
    (min-amt-out uint)
  )
  (begin
    (try! (contract-call? 'SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token-v2
      transfer amt-in tx-sender current-contract none
    ))
    (let (
        (stx-out (try! (as-contract?
          ((with-ft 'SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token-v2
            "miamicoin" amt-in
          ))
          (try! (swap-token-to-stx-alex amt-in))
        )))
        (sbtc-out (try! (as-contract? ((with-stx stx-out))
          (try! (swap-stx-to-sbtc-velar stx-out))
        )))
        (amt-out (try! (as-contract?
          ((with-ft 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
            "sbtc-token" sbtc-out
          ))
          (try! (swap-sbtc-to-token sbtc-out))
        )))
      )
      (asserts! (>= amt-out min-amt-out) ERR-SLIPPAGE)
      (asserts! (> amt-out amt-in) ERR-NO-PROFIT)
      (try! (pay-deployer amt-out))
      (ok {
        token-in: amt-in,
        token-out: amt-out,
      })
    )
  )
)

(define-public (arb-alex-dlmm-fak
    (amt-in uint)
    (min-amt-out uint)
    (dlmm-pool uint)
  )
  (begin
    (try! (contract-call? 'SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token-v2
      transfer amt-in tx-sender current-contract none
    ))
    (let (
        (stx-out (try! (as-contract?
          ((with-ft 'SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token-v2
            "miamicoin" amt-in
          ))
          (try! (swap-token-to-stx-alex amt-in))
        )))
        (sbtc-out (try! (as-contract? ((with-stx stx-out))
          (try! (swap-stx-to-sbtc-dlmm dlmm-pool stx-out))
        )))
        (amt-out (try! (as-contract?
          ((with-ft 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
            "sbtc-token" sbtc-out
          ))
          (try! (swap-sbtc-to-token sbtc-out))
        )))
      )
      (asserts! (>= amt-out min-amt-out) ERR-SLIPPAGE)
      (asserts! (> amt-out amt-in) ERR-NO-PROFIT)
      (try! (pay-deployer amt-out))
      (ok {
        token-in: amt-in,
        token-out: amt-out,
      })
    )
  )
)

(define-private (pay-deployer (amt uint))
  (as-contract?
    ((with-ft 'SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token-v2
      "miamicoin" amt
    ))
    (try! (contract-call? 'SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token-v2
      transfer amt current-contract DEPLOYER none
    ))
  )
)

(define-private (swap-token-to-sbtc (amount uint))
  (let (
      (result (try! (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-core-v2
        execute 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.mia-pool-faktory
        amount (some 0x01)
      )))
      (raw-dy (get dy result))
    )
    (ok (- raw-dy (/ raw-dy u1000)))
  )
)

(define-private (swap-sbtc-to-token (sbtc-amount uint))
  (let ((result (try! (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-core-v2
      execute 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.mia-pool-faktory
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

(define-private (swap-sbtc-to-stx-dlmm
    (pool-ver uint)
    (sbtc-amount uint)
  )
  (let ((res (try! (if (is-eq pool-ver u1)
      (contract-call?
        'SM1FKXGNZJWSTWDWXQZJNF7B5TV5ZB235JTCXYXKD.dlmm-swap-router-v-1-2
        swap-y-for-x-simple-multi
        'SM1FKXGNZJWSTWDWXQZJNF7B5TV5ZB235JTCXYXKD.dlmm-pool-stx-sbtc-v-1-bps-15
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2
        'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token sbtc-amount u1
        none
      )
      (if (is-eq pool-ver u2)
        (contract-call?
          'SM1FKXGNZJWSTWDWXQZJNF7B5TV5ZB235JTCXYXKD.dlmm-swap-router-v-1-2
          swap-y-for-x-simple-multi
          'SM1FKXGNZJWSTWDWXQZJNF7B5TV5ZB235JTCXYXKD.dlmm-pool-stx-sbtc-v-2-bps-15
          'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2
          'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token sbtc-amount u1
          none
        )
        (contract-call?
          'SM1FKXGNZJWSTWDWXQZJNF7B5TV5ZB235JTCXYXKD.dlmm-swap-router-v-1-2
          swap-y-for-x-simple-multi
          'SM1FKXGNZJWSTWDWXQZJNF7B5TV5ZB235JTCXYXKD.dlmm-pool-stx-sbtc-v-3-bps-15
          'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2
          'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token sbtc-amount u1
          none
        )
      )
    ))))
    (asserts! (is-eq (get in res) sbtc-amount) ERR-PARTIAL-FILL)
    (ok (get out res))
  )
)

(define-private (swap-stx-to-sbtc-dlmm
    (pool-ver uint)
    (stx-amount uint)
  )
  (let ((res (try! (if (is-eq pool-ver u1)
      (contract-call?
        'SM1FKXGNZJWSTWDWXQZJNF7B5TV5ZB235JTCXYXKD.dlmm-swap-router-v-1-2
        swap-x-for-y-simple-multi
        'SM1FKXGNZJWSTWDWXQZJNF7B5TV5ZB235JTCXYXKD.dlmm-pool-stx-sbtc-v-1-bps-15
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2
        'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token stx-amount u1
        none
      )
      (if (is-eq pool-ver u2)
        (contract-call?
          'SM1FKXGNZJWSTWDWXQZJNF7B5TV5ZB235JTCXYXKD.dlmm-swap-router-v-1-2
          swap-x-for-y-simple-multi
          'SM1FKXGNZJWSTWDWXQZJNF7B5TV5ZB235JTCXYXKD.dlmm-pool-stx-sbtc-v-2-bps-15
          'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2
          'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token stx-amount u1
          none
        )
        (contract-call?
          'SM1FKXGNZJWSTWDWXQZJNF7B5TV5ZB235JTCXYXKD.dlmm-swap-router-v-1-2
          swap-x-for-y-simple-multi
          'SM1FKXGNZJWSTWDWXQZJNF7B5TV5ZB235JTCXYXKD.dlmm-pool-stx-sbtc-v-3-bps-15
          'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2
          'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token stx-amount u1
          none
        )
      )
    ))))
    (asserts! (is-eq (get in res) stx-amount) ERR-PARTIAL-FILL)
    (ok (get out res))
  )
)

(define-private (swap-stx-to-token-alex (stx-amount uint))
  (let ((result (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01
      swap-x-for-y 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v2
      'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wmia u100000000
      (* stx-amount u100) none
    ))))
    (ok (/ (get dy result) u100))
  )
)

(define-private (swap-token-to-stx-alex (amount uint))
  (let ((result (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01
      swap-y-for-x 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v2
      'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wmia u100000000
      (* amount u100) none
    ))))
    (ok (/ (get dx result) u100))
  )
)

(define-read-only (simulate-token-to-sbtc (amount uint))
  (let ((q (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.mia-pool-faktory
      get-swap-quote amount (some 0x01)
    )))
    (- (get dy q) (get fee q))
  )
)

(define-read-only (simulate-sbtc-to-token (sbtc-amount uint))
  (get dy
    (unwrap-panic (contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.mia-pool-faktory
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

(define-read-only (simulate-stx-to-token-alex (stx-amount uint))
  (let (
      (stx-8dec (* stx-amount u100))
      (fee (/ (+ (* stx-8dec u500000) u99999999) u100000000))
      (stx-net (if (<= stx-8dec fee)
        u0
        (- stx-8dec fee)
      ))
    )
    (/
      (unwrap-panic (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01
        get-y-given-x 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v2
        'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wmia u100000000
        stx-net
      ))
      u100
    )
  )
)

(define-read-only (simulate-token-to-stx-alex (amount uint))
  (let (
      (token-8dec (* amount u100))
      (fee (/ (+ (* token-8dec u500000) u99999999) u100000000))
      (token-net (if (<= token-8dec fee)
        u0
        (- token-8dec fee)
      ))
    )
    (/
      (unwrap-panic (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01
        get-x-given-y 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v2
        'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wmia u100000000
        token-net
      ))
      u100
    )
  )
)

(define-read-only (check-fak-bit-alex (amt-in uint))
  (let (
      (sbtc-estimate (simulate-token-to-sbtc amt-in))
      (stx-estimate (simulate-sbtc-to-stx sbtc-estimate))
      (amt-estimate (simulate-stx-to-token-alex stx-estimate))
      (profit (if (> amt-estimate amt-in)
        (- amt-estimate amt-in)
        u0
      ))
    )
    (ok {
      amt-in: amt-in,
      sbtc-out: sbtc-estimate,
      stx-out: stx-estimate,
      amt-out: amt-estimate,
      profit: profit,
      profitable: (> amt-estimate amt-in),
    })
  )
)

(define-read-only (check-fak-vel-alex (amt-in uint))
  (let (
      (sbtc-estimate (simulate-token-to-sbtc amt-in))
      (stx-estimate (simulate-sbtc-to-stx-velar sbtc-estimate))
      (amt-estimate (simulate-stx-to-token-alex stx-estimate))
      (profit (if (> amt-estimate amt-in)
        (- amt-estimate amt-in)
        u0
      ))
    )
    (ok {
      amt-in: amt-in,
      sbtc-out: sbtc-estimate,
      stx-out: stx-estimate,
      amt-out: amt-estimate,
      profit: profit,
      profitable: (> amt-estimate amt-in),
    })
  )
)

(define-read-only (check-alex-bit-fak (amt-in uint))
  (let (
      (stx-estimate (simulate-token-to-stx-alex amt-in))
      (sbtc-estimate (simulate-stx-to-sbtc stx-estimate))
      (amt-estimate (simulate-sbtc-to-token sbtc-estimate))
      (profit (if (> amt-estimate amt-in)
        (- amt-estimate amt-in)
        u0
      ))
    )
    (ok {
      amt-in: amt-in,
      stx-out: stx-estimate,
      sbtc-out: sbtc-estimate,
      amt-out: amt-estimate,
      profit: profit,
      profitable: (> amt-estimate amt-in),
    })
  )
)

(define-read-only (check-alex-vel-fak (amt-in uint))
  (let (
      (stx-estimate (simulate-token-to-stx-alex amt-in))
      (sbtc-estimate (simulate-stx-to-sbtc-velar stx-estimate))
      (amt-estimate (simulate-sbtc-to-token sbtc-estimate))
      (profit (if (> amt-estimate amt-in)
        (- amt-estimate amt-in)
        u0
      ))
    )
    (ok {
      amt-in: amt-in,
      stx-out: stx-estimate,
      sbtc-out: sbtc-estimate,
      amt-out: amt-estimate,
      profit: profit,
      profitable: (> amt-estimate amt-in),
    })
  )
)

(define-public (rescue-sbtc (amount uint))
  (begin
    (asserts! (is-eq tx-sender DEPLOYER) ERR-NOT-AUTHORIZED)
    (as-contract?
      ((with-ft 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token "sbtc-token"
        amount
      ))
      (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
        transfer amount current-contract DEPLOYER none
      ))
    )
  )
)

(define-public (rescue-token (amount uint))
  (begin
    (asserts! (is-eq tx-sender DEPLOYER) ERR-NOT-AUTHORIZED)
    (as-contract?
      ((with-ft 'SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token-v2
        "miamicoin" amount
      ))
      (try! (contract-call?
        'SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token-v2 transfer
        amount current-contract DEPLOYER none
      ))
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
