(define-constant ERR-SLIPPAGE (err u1000))
(define-constant ERR-NO-PROFIT (err u1001))
(define-constant ERR-INVALID-RATIO (err u1002))

(define-constant CONTRACT (as-contract tx-sender))
(define-constant SAINT 'SP000000000000000000002Q6VF78)

(define-constant ALEX-POOL-ID u175)

;; sBTC -> B token via multiple routes
(define-public (buy-b-from-sbtc
    (sbtc-amount uint)
    (min-b-out uint)
    (fak-ratio uint)  
    (bit-vel-flag bool))  
    ;; Ratio for FAK route (0-100)
    ;; true for Bitflow, false for Velar
  (let (
    (total-ratio u100)  ;; Total ratio (100%)
    (fak-amount (/ (* sbtc-amount fak-ratio) total-ratio))
    (dex-amount (- sbtc-amount fak-amount))
  )
    ;; Validate ratio
    (asserts! (<= fak-ratio total-ratio) ERR-INVALID-RATIO)
    
    ;; Transfer sBTC from user to contract
    (try! (contract-call? 
      'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token 
      transfer 
      sbtc-amount 
      tx-sender 
      CONTRACT
      none
    ))
    
    ;; Route 1: Direct sBTC->B via faktory pool
    (let (
      (b-from-fak (if (> fak-amount u0)
                      (try! (as-contract (swap-sbtc-to-token fak-amount)))
                      u0))
      
      ;; Route 2: sBTC->STX->B via selected DEX
      (stx-from-dex (if (> dex-amount u0)
                        (if bit-vel-flag
                            (try! (as-contract (swap-sbtc-to-stx dex-amount)))
                            (try! (as-contract (swap-sbtc-to-stx-velar dex-amount))))
                        u0))
      (b-from-dex (if (> stx-from-dex u0)
                      (try! (as-contract (swap-stx-to-token stx-from-dex)))
                      u0))
      
      ;; Total output
      (total-b-out (+ b-from-fak b-from-dex))
    )
      ;; Check minimum output
      (asserts! (>= total-b-out min-b-out) ERR-SLIPPAGE)
      
      ;; Transfer B tokens to user
      (try! (as-contract (contract-call? 
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory 
        transfer 
        total-b-out 
        CONTRACT 
        tx-sender
        none
      )))
      
      (ok {
        sbtc-amount: sbtc-amount,
        b-from-fak: b-from-fak,
        b-from-dex: b-from-dex,
        total-b-out: total-b-out
      })
    )
  )
)

;; STX -> B token via multiple routes
(define-public (buy-b-from-stx
    (stx-amount uint)
    (min-b-out uint)
    (vel-ratio uint)  ;; Ratio for Velar direct route (0-100)
    (bit-vel-flag bool))  ;; true for Bitflow, false for Velar for STX->sBTC
  (let (
    (total-ratio u100)  ;; Total ratio (100%)
    (vel-amount (/ (* stx-amount vel-ratio) total-ratio))
    (dex-amount (- stx-amount vel-amount))
  )
    ;; Validate ratio
    (asserts! (<= vel-ratio total-ratio) ERR-INVALID-RATIO)
    
    ;; Transfer STX from user to contract
    (try! (stx-transfer? stx-amount tx-sender CONTRACT))
    
    ;; Route 1: Direct STX->B via Velar
    (let (
      (b-from-vel (if (> vel-amount u0)
                      (try! (as-contract (swap-stx-to-token vel-amount)))
                      u0))
      
      ;; Route 2: STX->sBTC->B via selected DEX
      (sbtc-from-dex (if (> dex-amount u0)
                         (if bit-vel-flag
                             (try! (as-contract (swap-stx-to-sbtc dex-amount)))
                             (try! (as-contract (swap-stx-to-sbtc-velar dex-amount))))
                         u0))
      (b-from-dex (if (> sbtc-from-dex u0)
                      (try! (as-contract (swap-sbtc-to-token sbtc-from-dex)))
                      u0))
      
      ;; Total output
      (total-b-out (+ b-from-vel b-from-dex))
    )
      ;; Check minimum output
      (asserts! (>= total-b-out min-b-out) ERR-SLIPPAGE)
      
      ;; Transfer B tokens to user
      (try! (as-contract (contract-call? 
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory 
        transfer 
        total-b-out 
        CONTRACT 
        tx-sender
        none
      )))
      
      (ok {
        stx-amount: stx-amount,
        b-from-vel: b-from-vel,
        b-from-dex: b-from-dex,
        total-b-out: total-b-out
      })
    )
  )
)

;; B token -> sBTC via multiple routes
(define-public (sell-b-for-sbtc
    (b-amount uint)
    (min-sbtc-out uint)
    (fak-ratio uint)  ;; Ratio for FAK route (0-100)
    (bit-vel-flag bool))  ;; true for Bitflow, false for Velar
  (let (
    (total-ratio u100)  ;; Total ratio (100%)
    (fak-amount (/ (* b-amount fak-ratio) total-ratio))
    (dex-amount (- b-amount fak-amount))
  )
    ;; Validate ratio
    (asserts! (<= fak-ratio total-ratio) ERR-INVALID-RATIO)
    
    ;; Transfer B tokens from user to contract
    (try! (contract-call? 
      'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory 
      transfer 
      b-amount 
      tx-sender 
      CONTRACT
      none
    ))
    
    ;; Route 1: Direct B->sBTC via faktory pool
    (let (
      (sbtc-from-fak (if (> fak-amount u0)
                         (try! (as-contract (swap-token-to-sbtc fak-amount)))
                         u0))
      
      ;; Route 2: B->STX->sBTC via selected DEX
      (stx-from-vel (if (> dex-amount u0)
                        (try! (as-contract (swap-token-to-stx dex-amount)))
                        u0))
      (sbtc-from-dex (if (> stx-from-vel u0)
                         (if bit-vel-flag
                             (try! (as-contract (swap-stx-to-sbtc stx-from-vel)))
                             (try! (as-contract (swap-stx-to-sbtc-velar stx-from-vel))))
                         u0))
      
      ;; Total output
      (total-sbtc-out (+ sbtc-from-fak sbtc-from-dex))
    )
      ;; Check minimum output
      (asserts! (>= total-sbtc-out min-sbtc-out) ERR-SLIPPAGE)
      
      ;; Transfer sBTC to user
      (try! (as-contract (contract-call? 
        'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
        transfer 
        total-sbtc-out 
        CONTRACT 
        tx-sender
        none
      )))
      
      (ok {
        b-amount: b-amount,
        sbtc-from-fak: sbtc-from-fak,
        sbtc-from-dex: sbtc-from-dex,
        total-sbtc-out: total-sbtc-out
      })
    )
  )
)

;; B token -> STX via multiple routes
(define-public (sell-b-for-stx
    (b-amount uint)
    (min-stx-out uint)
    (vel-ratio uint)  ;; Ratio for Velar direct route (0-100)
    (bit-vel-flag bool))  ;; true for Bitflow, false for Velar for sBTC->STX
  (let (
    (total-ratio u100)  ;; Total ratio (100%)
    (vel-amount (/ (* b-amount vel-ratio) total-ratio))
    (dex-amount (- b-amount vel-amount))
  )
    ;; Validate ratio
    (asserts! (<= vel-ratio total-ratio) ERR-INVALID-RATIO)
    
    ;; Transfer B tokens from user to contract
    (try! (contract-call? 
      'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory 
      transfer 
      b-amount 
      tx-sender 
      CONTRACT
      none
    ))
    
    ;; Route 1: Direct B->STX via Velar
    (let (
      (stx-from-vel (if (> vel-amount u0)
                        (try! (as-contract (swap-token-to-stx vel-amount)))
                        u0))
      
      ;; Route 2: B->sBTC->STX via selected DEX
      (sbtc-from-fak (if (> dex-amount u0)
                         (try! (as-contract (swap-token-to-sbtc dex-amount)))
                         u0))
      (stx-from-dex (if (> sbtc-from-fak u0)
                        (if bit-vel-flag
                            (try! (as-contract (swap-sbtc-to-stx sbtc-from-fak)))
                            (try! (as-contract (swap-sbtc-to-stx-velar sbtc-from-fak))))
                        u0))
      
      ;; Total output
      (total-stx-out (+ stx-from-vel stx-from-dex))
    )
      ;; Check minimum output
      (asserts! (>= total-stx-out min-stx-out) ERR-SLIPPAGE)
      
      ;; Transfer STX to user
      (try! (as-contract (stx-transfer? total-stx-out CONTRACT tx-sender)))
      
      (ok {
        b-amount: b-amount,
        stx-from-vel: stx-from-vel,
        stx-from-dex: stx-from-dex,
        total-stx-out: total-stx-out
      })
    )
  )
)

;; Helper to calculate optimal ratio between routes based on liquidity
(define-read-only (calculate-optimal-ratio-sbtc-to-b (bit-vel-flag bool))
  (let (
    ;; Get liquidity stats for the routes
    (fak-sbtc-b-liquidity (get-fak-sbtc-b-liquidity))
    (stx-b-liquidity (get-velar-stx-b-liquidity))
    (sbtc-stx-liquidity (if bit-vel-flag
                          (get-bit-sbtc-stx-liquidity)
                          (get-velar-sbtc-stx-liquidity)))
    
    ;; Convert STX liquidity to sBTC equivalent using the sBTC/STX rate
    (stx-in-sbtc-ratio (/ sbtc-stx-liquidity.x-balance sbtc-stx-liquidity.y-balance)) 
    (stx-b-in-sbtc (/ stx-b-liquidity stx-in-sbtc-ratio))
    
    ;; Calculate ratio
    (total-liquidity (+ fak-sbtc-b-liquidity stx-b-in-sbtc))
    (fak-percentage (/ (* fak-sbtc-b-liquidity u100) total-liquidity))
  )
    {
      fak-ratio: fak-percentage,
      dex-ratio: (- u100 fak-percentage),
      fak-liquidity: fak-sbtc-b-liquidity,
      dex-liquidity-sbtc-equiv: stx-b-in-sbtc,
      total-liquidity-sbtc-equiv: total-liquidity
    }
  )
)

;; Helper to calculate optimal ratio for STX to B routes
(define-read-only (calculate-optimal-ratio-stx-to-b (bit-vel-flag bool))
  (let (
    ;; Get liquidity stats for the routes
    (velar-stx-b-liquidity (get-velar-stx-b-liquidity))
    (fak-sbtc-b-liquidity (get-fak-sbtc-b-liquidity))
    (sbtc-stx-liquidity (if bit-vel-flag
                          (get-bit-sbtc-stx-liquidity)
                          (get-velar-sbtc-stx-liquidity)))
    
    ;; Convert sBTC liquidity to STX equivalent using the sBTC/STX rate
    (sbtc-in-stx-ratio (/ sbtc-stx-liquidity.y-balance sbtc-stx-liquidity.x-balance))
    (fak-sbtc-b-in-stx (/ fak-sbtc-b-liquidity sbtc-in-stx-ratio))
    
    ;; Calculate ratio
    (total-liquidity (+ velar-stx-b-liquidity fak-sbtc-b-in-stx))
    (velar-percentage (/ (* velar-stx-b-liquidity u100) total-liquidity))
  )
    {
      velar-ratio: velar-percentage,
      dex-ratio: (- u100 velar-percentage),
      velar-liquidity: velar-stx-b-liquidity,
      dex-liquidity-stx-equiv: fak-sbtc-b-in-stx,
      total-liquidity-stx-equiv: total-liquidity
    }
  )
)

;; Helper functions to get liquidity data from various pools
(define-read-only (get-fak-sbtc-b-liquidity)
  (let (
    (pool-data (contract-call? 
      'SP6SA6BTPNN5WDAWQ7GWJF1T5E2KWY01K9SZDBJQ.b-faktory-pool-v2
      get-reserves))
  )
    (get sbtc pool-data)  ;; Return sBTC liquidity
  )
)

(define-read-only (get-velar-stx-b-liquidity)
  (let ((pool (contract-call? 
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-core 
        get-pool 
        VELAR-POOL-ID)))
    (get reserve0 pool)  ;; Return STX liquidity
  )
)

(define-read-only (get-bit-sbtc-stx-liquidity)
  (let (
    (pool (contract-call?
      'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1
      get-pool
    ))
  )
    {
      x-balance: (get x-balance pool),  ;; sBTC liquidity
      y-balance: (get y-balance pool)   ;; STX liquidity
    }
  )
)

(define-read-only (get-velar-sbtc-stx-liquidity)
  (let ((pool (contract-call? 
        'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070
        get-pool)))
    {
      x-balance: (get reserve1 pool),  ;; sBTC liquidity 
      y-balance: (get reserve0 pool)   ;; STX liquidity
    }
  )
)

;; Read-only function to estimate optimal output for sBTC to B swap
(define-read-only (estimate-sbtc-to-b (sbtc-amount uint) (bit-vel-flag bool))
  (let (
    ;; Get optimal ratio
    (ratio-data (calculate-optimal-ratio-sbtc-to-b bit-vel-flag))
    (fak-ratio (get fak-ratio ratio-data))
    (dex-ratio (get dex-ratio ratio-data))
    
    ;; Calculate amounts for each route
    (fak-amount (/ (* sbtc-amount fak-ratio) u100))
    (dex-amount (/ (* sbtc-amount dex-ratio) u100))
    
    ;; Estimate outputs
    (b-from-fak (simulate-sbtc-to-token fak-amount))
    (stx-from-dex (if bit-vel-flag
                     (simulate-sbtc-to-stx dex-amount)
                     (simulate-sbtc-to-stx-velar dex-amount)))
    (b-from-dex (simulate-stx-to-token stx-from-dex))
    
    ;; Total output
    (total-b-out (+ b-from-fak b-from-dex))
  )
    (ok {
      sbtc-amount: sbtc-amount,
      optimal-fak-ratio: fak-ratio,
      fak-amount: fak-amount,
      dex-amount: dex-amount,
      b-from-fak: b-from-fak,
      b-from-dex: b-from-dex,
      total-b-out: total-b-out
    })
  )
)

;; Read-only function to estimate optimal output for STX to B swap
(define-read-only (estimate-stx-to-b (stx-amount uint) (bit-vel-flag bool))
  (let (
    ;; Get optimal ratio
    (ratio-data (calculate-optimal-ratio-stx-to-b bit-vel-flag))
    (velar-ratio (get velar-ratio ratio-data))
    (dex-ratio (get dex-ratio ratio-data))
    
    ;; Calculate amounts for each route
    (velar-amount (/ (* stx-amount velar-ratio) u100))
    (dex-amount (/ (* stx-amount dex-ratio) u100))
    
    ;; Estimate outputs
    (b-from-vel (simulate-stx-to-token velar-amount))
    (sbtc-from-dex (if bit-vel-flag
                      (simulate-stx-to-sbtc dex-amount)
                      (simulate-stx-to-sbtc-velar dex-amount)))
    (b-from-dex (simulate-sbtc-to-token sbtc-from-dex))
    
    ;; Total output
    (total-b-out (+ b-from-vel b-from-dex))
  )
    (ok {
      stx-amount: stx-amount,
      optimal-velar-ratio: velar-ratio,
      velar-amount: velar-amount,
      dex-amount: dex-amount,
      b-from-vel: b-from-vel,
      b-from-dex: b-from-dex,
      total-b-out: total-b-out
    })
  )
)

;; Simulation/swap functions from your original contract
(define-private (swap-token-to-sbtc (token-amount uint))
  (let (
      (result (try! (contract-call? 
        'SP6SA6BTPNN5WDAWQ7GWJF1T5E2KWY01K9SZDBJQ.b-faktory-pool-v2
        execute
        token-amount
        (some 0x01) 
      )))
    )
    (ok (get dy result))
  )
)

(define-private (swap-sbtc-to-token (sbtc-amount uint))
  (let (
      (result (try! (contract-call? 
        'SP6SA6BTPNN5WDAWQ7GWJF1T5E2KWY01K9SZDBJQ.b-faktory-pool-v2
        execute
        sbtc-amount
        (some 0x00) 
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

(define-private (swap-stx-to-token (stx-amount uint))
  (let (
      (result (try! (contract-call?
        'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01
        swap-x-for-y
        'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v2
        'SP1KK89R86W73SJE6RQNQPRDM471008S9JY4FQA62.token-wbfaktory
        u100000000
        stx-amount 
        none
      )))
    )
    (ok (get dy result))
  )
)

(define-private (swap-token-to-stx (token-amount uint))
  (let (
      (result (try! (contract-call?
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-router
        swap-exact-tokens-for-tokens
        VELAR-POOL-ID
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to
        token-amount
        u1
      )))
    )
    (ok (get amt-out result))
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

;; Simulation functions
(define-read-only (simulate-token-to-sbtc (token-amount uint))
  (get dy (unwrap-panic (contract-call? 
    'SP6SA6BTPNN5WDAWQ7GWJF1T5E2KWY01K9SZDBJQ.b-faktory-pool-v2
    quote
    token-amount
    (some 0x01) 
  )))
)

(define-read-only (simulate-sbtc-to-token (sbtc-amount uint))
  (get dy (unwrap-panic (contract-call? 
    'SP6SA6BTPNN5WDAWQ7GWJF1T5E2KWY01K9SZDBJQ.b-faktory-pool-v2
    quote
    sbtc-amount
    (some 0x00) 
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

(define-read-only (simulate-stx-to-token (stx-amount uint))
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

(define-read-only (simulate-token-to-stx (token-amount uint))
  (let ((pool (unwrap-panic (contract-call? 
          'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-core 
          get-pool 
          VELAR-POOL-ID)))
        (r0 (get reserve0 pool))
        (r1 (get reserve1 pool))
        (swap-fee (get swap-fee pool))
        (amt-in-adjusted (/ (* token-amount (get num swap-fee)) (get den swap-fee)))
        (amt-out (/ (* r0 amt-in-adjusted) (+ r1 amt-in-adjusted)))
  )
  amt-out)
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

;; Helper read-only functions to compare different routes
(define-read-only (compare-sbtc-to-b-routes (sbtc-amount uint))
  (let (
    ;; Get estimates for different route combinations
    (route-bit (unwrap-panic (estimate-sbtc-to-b sbtc-amount true)))
    (route-vel (unwrap-panic (estimate-sbtc-to-b sbtc-amount false)))
    
    ;; Compare outputs
    (best-route (if (> (get total-b-out route-bit) (get total-b-out route-vel)) 
                   "BitFlow" 
                   "Velar"))
    (best-output (if (> (get total-b-out route-bit) (get total-b-out route-vel))
                    (get total-b-out route-bit)
                    (get total-b-out route-vel)))
    (best-fak-ratio (if (> (get total-b-out route-bit) (get total-b-out route-vel))
                       (get optimal-fak-ratio route-bit)
                       (get optimal-fak-ratio route-vel)))
  )
    {
      sbtc-amount: sbtc-amount,
      best-route: best-route,
      best-output: best-output,
      best-fak-ratio: best-fak-ratio,
      bit-output: (get total-b-out route-bit),
      vel-output: (get total-b-out route-vel),
      bit-fak-ratio: (get optimal-fak-ratio route-bit),
      vel-fak-ratio: (get optimal-fak-ratio route-vel)
    }
  )
)

(define-read-only (compare-stx-to-b-routes (stx-amount uint))
  (let (
    ;; Get estimates for different route combinations
    (route-bit (unwrap-panic (estimate-stx-to-b stx-amount true)))
    (route-vel (unwrap-panic (estimate-stx-to-b stx-amount false)))
    
    ;; Compare outputs
    (best-route (if (> (get total-b-out route-bit) (get total-b-out route-vel)) 
                   "BitFlow" 
                   "Velar"))
    (best-output (if (> (get total-b-out route-bit) (get total-b-out route-vel))
                    (get total-b-out route-bit)
                    (get total-b-out route-vel)))
    (best-velar-ratio (if (> (get total-b-out route-bit) (get total-b-out route-vel))
                         (get optimal-velar-ratio route-bit)
                         (get optimal-velar-ratio route-vel)))
  )
    {
      stx-amount: stx-amount,
      best-route: best-route,
      best-output: best-output,
      best-velar-ratio: best-velar-ratio,
      bit-output: (get total-b-out route-bit),
      vel-output: (get total-b-out route-vel),
      bit-velar-ratio: (get optimal-velar-ratio route-bit),
      vel-velar-ratio: (get optimal-velar-ratio route-vel)
    }
  )
)

;; Convenience functions that automatically use the best route and ratio
(define-public (smart-buy-b-from-sbtc
    (sbtc-amount uint)
    (min-b-out uint))
  (let (
    (best-route (compare-sbtc-to-b-routes sbtc-amount))
    (use-bit (is-eq (get best-route best-route) "BitFlow"))
    (fak-ratio (get best-fak-ratio best-route))
  )
    (try! (buy-b-from-sbtc sbtc-amount min-b-out fak-ratio use-bit))
    (ok {
      sbtc-amount: sbtc-amount,
      b-out: (get best-output best-route),
      route-used: (get best-route best-route),
      fak-ratio-used: fak-ratio
    })
  )
)

(define-public (smart-buy-b-from-stx
    (stx-amount uint)
    (min-b-out uint))
  (let (
    (best-route (compare-stx-to-b-routes stx-amount))
    (use-bit (is-eq (get best-route best-route) "BitFlow"))
    (velar-ratio (get best-velar-ratio best-route))
  )
    (try! (buy-b-from-stx stx-amount min-b-out velar-ratio use-bit))
    (ok {
      stx-amount: stx-amount,
      b-out: (get best-output best-route),
      route-used: (get best-route best-route),
      velar-ratio-used: velar-ratio
    })
  )
)

;; Similar read-only functions for selling B tokens
(define-read-only (estimate-b-to-sbtc (b-amount uint) (bit-vel-flag bool))
  (let (
    ;; For sell routes, we need to invert the ratios from the buy routes
    ;; This is because the optimal buy ratio might not be the optimal sell ratio
    ;; due to differences in pool reserves and pricing
    (ratio-data (calculate-optimal-ratio-sbtc-to-b bit-vel-flag))
    (fak-ratio (get fak-ratio ratio-data))
    (dex-ratio (get dex-ratio ratio-data))
    
    ;; Calculate amounts for each route
    (fak-amount (/ (* b-amount fak-ratio) u100))
    (dex-amount (/ (* b-amount dex-ratio) u100))
    
    ;; Estimate outputs
    (sbtc-from-fak (simulate-token-to-sbtc fak-amount))
    (stx-from-dex (simulate-token-to-stx dex-amount))
    (sbtc-from-stx (if bit-vel-flag
                     (simulate-stx-to-sbtc stx-from-dex)
                     (simulate-stx-to-sbtc-velar stx-from-dex)))
    
    ;; Total output
    (total-sbtc-out (+ sbtc-from-fak sbtc-from-stx))
  )
    (ok {
      b-amount: b-amount,
      optimal-fak-ratio: fak-ratio,
      fak-amount: fak-amount,
      dex-amount: dex-amount,
      sbtc-from-fak: sbtc-from-fak,
      sbtc-from-stx: sbtc-from-stx,
      total-sbtc-out: total-sbtc-out
    })
  )
)

(define-read-only (estimate-b-to-stx (b-amount uint) (bit-vel-flag bool))
  (let (
    ;; For sell routes, we need to invert the ratios from the buy routes
    (ratio-data (calculate-optimal-ratio-stx-to-b bit-vel-flag))
    (velar-ratio (get velar-ratio ratio-data))
    (dex-ratio (get dex-ratio ratio-data))
    
    ;; Calculate amounts for each route
    (velar-amount (/ (* b-amount velar-ratio) u100))
    (dex-amount (/ (* b-amount dex-ratio) u100))
    
    ;; Estimate outputs
    (stx-from-velar (simulate-token-to-stx velar-amount))
    (sbtc-from-dex (simulate-token-to-sbtc dex-amount))
    (stx-from-sbtc (if bit-vel-flag
                      (simulate-sbtc-to-stx sbtc-from-dex)
                      (simulate-sbtc-to-stx-velar sbtc-from-dex)))
    
    ;; Total output
    (total-stx-out (+ stx-from-velar stx-from-sbtc))
  )
    (ok {
      b-amount: b-amount,
      optimal-velar-ratio: velar-ratio,
      velar-amount: velar-amount,
      dex-amount: dex-amount,
      stx-from-velar: stx-from-velar,
      stx-from-sbtc: stx-from-sbtc,
      total-stx-out: total-stx-out
    })
  )
)

(define-read-only (compare-b-to-sbtc-routes (b-amount uint))
  (let (
    ;; Get estimates for different route combinations
    (route-bit (unwrap-panic (estimate-b-to-sbtc b-amount true)))
    (route-vel (unwrap-panic (estimate-b-to-sbtc b-amount false)))
    
    ;; Compare outputs
    (best-route (if (> (get total-sbtc-out route-bit) (get total-sbtc-out route-vel)) 
                   "BitFlow" 
                   "Velar"))
    (best-output (if (> (get total-sbtc-out route-bit) (get total-sbtc-out route-vel))
                    (get total-sbtc-out route-bit)
                    (get total-sbtc-out route-vel)))
    (best-fak-ratio (if (> (get total-sbtc-out route-bit) (get total-sbtc-out route-vel))
                       (get optimal-fak-ratio route-bit)
                       (get optimal-fak-ratio route-vel)))
  )
    {
      b-amount: b-amount,
      best-route: best-route,
      best-output: best-output,
      best-fak-ratio: best-fak-ratio,
      bit-output: (get total-sbtc-out route-bit),
      vel-output: (get total-sbtc-out route-vel),
      bit-fak-ratio: (get optimal-fak-ratio route-bit),
      vel-fak-ratio: (get optimal-fak-ratio route-vel)
    }
  )
)

(define-read-only (compare-b-to-stx-routes (b-amount uint))
  (let (
    ;; Get estimates for different route combinations
    (route-bit (unwrap-panic (estimate-b-to-stx b-amount true)))
    (route-vel (unwrap-panic (estimate-b-to-stx b-amount false)))
    
    ;; Compare outputs
    (best-route (if (> (get total-stx-out route-bit) (get total-stx-out route-vel)) 
                   "BitFlow" 
                   "Velar"))
    (best-output (if (> (get total-stx-out route-bit) (get total-stx-out route-vel))
                    (get total-stx-out route-bit)
                    (get total-stx-out route-vel)))
    (best-velar-ratio (if (> (get total-stx-out route-bit) (get total-stx-out route-vel))
                         (get optimal-velar-ratio route-bit)
                         (get optimal-velar-ratio route-vel)))
  )
    {
      b-amount: b-amount,
      best-route: best-route,
      best-output: best-output,
      best-velar-ratio: best-velar-ratio,
      bit-output: (get total-stx-out route-bit),
      vel-output: (get total-stx-out route-vel),
      bit-velar-ratio: (get optimal-velar-ratio route-bit),
      vel-velar-ratio: (get optimal-velar-ratio route-vel)
    }
  )
)

;; Convenience functions for selling B with the best route and ratio
(define-public (smart-sell-b-for-sbtc
    (b-amount uint)
    (min-sbtc-out uint))
  (let (
    (best-route (compare-b-to-sbtc-routes b-amount))
    (use-bit (is-eq (get best-route best-route) "BitFlow"))
    (fak-ratio (get best-fak-ratio best-route))
  )
    (try! (sell-b-for-sbtc b-amount min-sbtc-out fak-ratio use-bit))
    (ok {
      b-amount: b-amount,
      sbtc-out: (get best-output best-route),
      route-used: (get best-route best-route),
      fak-ratio-used: fak-ratio
    })
  )
)

(define-public (smart-sell-b-for-stx
    (b-amount uint)
    (min-stx-out uint))
  (let (
    (best-route (compare-b-to-stx-routes b-amount))
    (use-bit (is-eq (get best-route best-route) "BitFlow"))
    (velar-ratio (get best-velar-ratio best-route))
  )
    (try! (sell-b-for-stx b-amount min-stx-out velar-ratio use-bit))
    (ok {
      b-amount: b-amount,
      stx-out: (get best-output best-route),
      route-used: (get best-route best-route),
      velar-ratio-used: velar-ratio
    })
  )
)