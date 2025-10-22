(define-constant ERR-SLIPPAGE (err u1000))
(define-constant ERR-NO-PROFIT (err u1001))
(define-constant ERR-INVALID-RATIO (err u1002))

(define-constant CONTRACT (as-contract tx-sender))
(define-constant SAINT 'SP000000000000000000002Q6VF78)

(define-constant ALEX-POOL-ID u175)
(define-constant TOTAL u100)

;; sBTC -> B token via multiple routes
(define-public (buy-with-sbtc
    (sbtc-amount uint)
    (min-token-out uint)
    (fak-ratio uint)  
    (flag bool))  
    ;; Ratio for FAK route (0-100)
    ;; true for Bitflow, false for Velar
  (let (
    (fak-amount (/ (* sbtc-amount fak-ratio) TOTAL))
    (alex-amount (- sbtc-amount fak-amount))
  )
    ;; Validate ratio
    (asserts! (<= fak-ratio TOTAL) ERR-INVALID-RATIO)
    
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
      (sender tx-sender)
      (token-from-fak (if (> fak-amount u0)
                      (try! (as-contract (swap-sbtc-to-token fak-amount)))
                      u0))
      
      ;; Route 2: sBTC->STX->B via selected DEX
      (stx-from-dex (if (> alex-amount u0)
                        (if flag
                            (try! (as-contract (swap-sbtc-to-stx alex-amount)))
                            (try! (as-contract (swap-sbtc-to-stx-velar alex-amount))))
                        u0))
   
      (token-from-alex (if (> stx-from-dex u0)
                      (try! (as-contract (swap-stx-to-token (* stx-from-dex u100))))
                      u0))
    ;; Total output
      (total-token-out (+ token-from-fak token-from-alex)))
    
      ;; Check minimum output
      (asserts! (>= total-token-out min-token-out) ERR-SLIPPAGE)
      
      ;; Transfer B tokens to user
      (try! (as-contract (contract-call? 
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory 
        transfer 
        total-token-out 
        CONTRACT 
        sender
        none
      )))
  
      (print {
        type: "buy",
        sender: tx-sender,
        token-in: 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token,
        amount-in: sbtc-amount,
        token-out: 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory,
        amount-out: total-token-out,
        token-from-fak: token-from-fak,
        token-from-dex: token-from-alex,
        pool-contract: CONTRACT,
        min-y-out: min-token-out })
      (ok {
        sbtc-amount: sbtc-amount,
        token-from-fak: token-from-fak,
        token-from-dex: token-from-alex,
        total-token-out: total-token-out
      })
    )
  )
)

;; STX -> B token via multiple routes
(define-public (buy-with-stx
    (stx-amount uint)
    (min-token-out uint)
    (alex-ratio uint)  
    (flag bool)) 
    ;; Ratio for Velar direct route (0-100)
     ;; true for Bitflow, false for Velar for STX->sBTC
  (let (
    (alex-amount (/ (* stx-amount alex-ratio) TOTAL))
    (fak-amount (- stx-amount alex-amount))
  )
    ;; Validate ratio
    (asserts! (<= alex-ratio TOTAL) ERR-INVALID-RATIO)
    
    ;; Transfer STX from user to contract
    (try! (stx-transfer? stx-amount tx-sender CONTRACT))
    
    ;; Route 1: Direct STX->B via Velar
    (let (
      (sender tx-sender)
      (token-from-alex (if (> alex-amount u0)
                      (try! (as-contract (swap-stx-to-token (* alex-amount u100))))
                      u0))
      
      ;; Route 2: STX->sBTC->B via selected DEX
      (sbtc-from-dex (if (> fak-amount u0)
                         (if flag
                             (try! (as-contract (swap-stx-to-sbtc fak-amount)))
                             (try! (as-contract (swap-stx-to-sbtc-velar fak-amount))))
                         u0))
      (token-from-fak (if (> sbtc-from-dex u0)
                      (try! (as-contract (swap-sbtc-to-token sbtc-from-dex)))
                      u0))
      
      ;; Total output
      (total-token-out (+ token-from-alex token-from-fak))
    )
      ;; Check minimum output
      (asserts! (>= total-token-out min-token-out) ERR-SLIPPAGE)
      
      ;; Transfer B tokens to user
      (try! (as-contract (contract-call? 
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory 
        transfer 
        total-token-out 
        CONTRACT 
        sender
        none
      )))
        (print {
        type: "buy",
        sender: tx-sender,
        token-in: 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx,
        amount-in: stx-amount,
        token-out: 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory,
        amount-out: total-token-out,
        token-from-alex: token-from-alex,
        token-from-dex: token-from-fak,
        pool-contract: CONTRACT,
        min-y-out: min-token-out
        })
      (ok {
        stx-amount: stx-amount,
        token-from-alex: token-from-alex,
        token-from-fak: token-from-fak,
        total-token-out: total-token-out
      })
    )
  )
)

;; B token -> sBTC via multiple routes
(define-public (sell-for-sbtc
    (token-amount uint)
    (min-sbtc-out uint)
    (fak-ratio uint)  
    (flag bool))  
    ;; Ratio for FAK route (0-100) ;; true for Bitflow, false for Velar
  (let (
    (fak-amount (/ (* token-amount fak-ratio) TOTAL))
    (alex-amount (- token-amount fak-amount))
  )
    ;; Validate ratio
    (asserts! (<= fak-ratio TOTAL) ERR-INVALID-RATIO)
    
    ;; Transfer B tokens from user to contract
    (try! (contract-call? 
      'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory 
      transfer 
      token-amount 
      tx-sender 
      CONTRACT
      none
    ))
    
    ;; Route 1: Direct B->sBTC via faktory pool
    (let (
      (sender tx-sender)
      (sbtc-from-fak (if (> fak-amount u0)
                         (try! (as-contract (swap-token-to-sbtc fak-amount)))
                         u0))
      
      ;; Route 2: B->STX->sBTC via selected DEX
      (stx-from-alex (if (> alex-amount u0)
                        (try! (as-contract (swap-token-to-stx alex-amount)))
                        u0))
      (sbtc-from-dex (if (> stx-from-alex u0)
                         (if flag
                             (try! (as-contract (swap-stx-to-sbtc (/ stx-from-alex u100))))
                             (try! (as-contract (swap-stx-to-sbtc-velar (/ stx-from-alex u100)))))
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
        sender
        none
      )))
      (print {
        type: "sell",
        sender: tx-sender,
        token-in: 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory,
        amount-in: token-amount, 
        token-out: 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token,
        amount-out: total-sbtc-out,
        sbtc-from-fak: sbtc-from-fak,
        sbtc-from-dex: sbtc-from-dex,
        pool-contract: CONTRACT,
        min-y-out: min-sbtc-out
      })
      (ok {
        token-amount: token-amount,
        sbtc-from-fak: sbtc-from-fak,
        sbtc-from-dex: sbtc-from-dex,
        total-sbtc-out: total-sbtc-out
      })
    )
  )
)

;; B token -> STX via multiple routes
(define-public (sell-for-stx
    (token-amount uint)
    (min-stx-out uint)
    (alex-ratio uint)  
    (flag bool))  ;; true for Bitflow, false for Velar for sBTC->STX ;; Ratio for Velar direct route (0-100)
  (let (
    (alex-amount (/ (* token-amount alex-ratio) TOTAL))
    (fak-amount (- token-amount alex-amount))
  )
    ;; Validate ratio
    (asserts! (<= alex-ratio TOTAL) ERR-INVALID-RATIO)
    
    ;; Transfer B tokens from user to contract
    (try! (contract-call? 
      'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory 
      transfer 
      token-amount 
      tx-sender 
      CONTRACT
      none
    ))
    
    ;; Route 1: Direct B->STX via Velar
    (let (
      (sender tx-sender)
      (stx-from-alex (if (> alex-amount u0)
                        (try! (as-contract (swap-token-to-stx alex-amount)))
                        u0))
      
      ;; Route 2: B->sBTC->STX via selected DEX
      (sbtc-from-fak (if (> fak-amount u0)
                         (try! (as-contract (swap-token-to-sbtc fak-amount)))
                         u0))
      (stx-from-dex (if (> sbtc-from-fak u0)
                        (if flag
                            (try! (as-contract (swap-sbtc-to-stx sbtc-from-fak)))
                            (try! (as-contract (swap-sbtc-to-stx-velar sbtc-from-fak))))
                        u0))
      
      ;; Total output
      (total-stx-out (+ (/ stx-from-alex u100) stx-from-dex))
    )
      ;; Check minimum output
      (asserts! (>= total-stx-out min-stx-out) ERR-SLIPPAGE)
      
      ;; Transfer STX to user
      (try! (as-contract (stx-transfer? total-stx-out CONTRACT sender)))
      (print {
        type: "sell",
        sender: tx-sender,
        token-in: 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory,
        amount-in: token-amount, 
        token-out: 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx,
        amount-out: total-stx-out,
        stx-from-alex: stx-from-alex,
        stx-from-dex: stx-from-dex,
        pool-contract: CONTRACT,
        min-y-out: min-stx-out
      })
      (ok {
        token-amount: token-amount,
        stx-from-alex: stx-from-alex,
        stx-from-dex: stx-from-dex,
        total-stx-out: total-stx-out
      })
    )
  )
)

;; Helper to calculate optimal ratio between routes based on liquidity
(define-read-only (calculate-optimal-ratio-sbtc-to-token (flag bool))
  (let (
    ;; Get liquidity stats for the routes
    (fak-sbtc-token-liquidity (get-fak-sbtc-token-liquidity))
    (alex-stx-token-liquidity (get-alex-stx-token-liquidity))
    (sbtc-stx-liquidity (if flag
                          (get-bit-sbtc-stx-liquidity)
                          (get-velar-sbtc-stx-liquidity)))
    
    ;; Convert STX liquidity to sBTC equivalent using the sBTC/STX rate
    (y-balance (get y-balance sbtc-stx-liquidity))
    (alex-stx-token-in-sbtc (if (> y-balance u0) (/ (* (/ alex-stx-token-liquidity u100) (get x-balance sbtc-stx-liquidity)) y-balance) u0)) 
    
    ;; Calculate ratio
    (total-liquidity (+ fak-sbtc-token-liquidity alex-stx-token-in-sbtc))
    (fak-percentage (if (> total-liquidity u0) (/ (* fak-sbtc-token-liquidity u100) total-liquidity) u0))
  )
    {
      fak-ratio: fak-percentage,
      dex-ratio: (- u100 fak-percentage),
      fak-liquidity: fak-sbtc-token-liquidity,
      dex-liquidity-sbtc-equiv: alex-stx-token-in-sbtc,
      total-liquidity-sbtc-equiv: total-liquidity
    }
  )
)

;; Helper to calculate optimal ratio for STX to B routes
(define-read-only (calculate-optimal-ratio-stx-to-token (flag bool))
  (let (
    ;; Get liquidity stats for the routes
    (alex-stx-token-liquidity (get-alex-stx-token-liquidity))
    (fak-sbtc-token-liquidity (get-fak-sbtc-token-liquidity))
    (sbtc-stx-liquidity (if flag
                          (get-bit-sbtc-stx-liquidity)
                          (get-velar-sbtc-stx-liquidity)))
    
    ;; Convert sBTC liquidity to STX equivalent using the sBTC/STX rate
    (x-balance (get x-balance sbtc-stx-liquidity))
    (fak-sbtc-token-in-stx (if (> x-balance u0) (/ (* fak-sbtc-token-liquidity (get y-balance sbtc-stx-liquidity)) x-balance) u0))

    ;; Calculate ratio
    (total-liquidity (+ (/ alex-stx-token-liquidity u100) fak-sbtc-token-in-stx))
    (alex-percentage (if (> total-liquidity u0) (/ alex-stx-token-liquidity total-liquidity) u0)) ;; already times 100
  )
    {
      alex-ratio: alex-percentage,
      dex-ratio: (- u100 alex-percentage),
      alex-liquidity: (/ alex-stx-token-liquidity u100),
      dex-liquidity-stx-equiv: fak-sbtc-token-in-stx,
      total-liquidity-stx-equiv: total-liquidity
    }
  )
)

;; Helper functions to get liquidity data from various pools
(define-read-only (get-fak-sbtc-token-liquidity)
  (let (
    (pool-data (contract-call? 
      'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory-pool
      get-reserves-quote))
  )
    (get dx pool-data)  ;; Return sBTC liquidity (dx)
  )
)

(define-read-only (get-alex-stx-token-liquidity)
     (let (
       (pool-data (unwrap-panic (contract-call?
         'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01
         get-pool-details
         'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v2
         'SP1KK89R86W73SJE6RQNQPRDM471008S9JY4FQA62.token-wbfaktory
         u100000000)))
     )
     (get balance-x pool-data)  ;; Return STX liquidity
     )
   )

(define-read-only (get-bit-sbtc-stx-liquidity)
  (let (
    (pool (unwrap-panic (contract-call?
      'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1
      get-pool
    )))
  )
    {
      x-balance: (get x-balance pool),  ;; sBTC liquidity = 10.65064974 sBTC
      y-balance: (get y-balance pool)   ;; STX liquidity = 26,582.28348505 STX
    }
  )
)

(define-read-only (get-velar-sbtc-stx-liquidity)
  (let ((pool (unwrap-panic (contract-call? 
        'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070
        get-pool)))
    )
    {
      x-balance: (get reserve1 pool),  ;; sBTC liquidity = 1.58944993 sBTC
      y-balance: (get reserve0 pool)   ;; STX liquidity = 3,986.13620056 STX
    }
  )
)

;; Read-only function to estimate optimal output for sBTC to B swap
(define-read-only (estimate-sbtc-to-token (sbtc-amount uint) (flag bool))
  (let (
    ;; Get optimal ratio
    (ratio-data (calculate-optimal-ratio-sbtc-to-token flag))
    (fak-ratio (get fak-ratio ratio-data))
    (dex-ratio (get dex-ratio ratio-data))
    
    ;; Calculate amounts for each route
    (fak-amount (/ (* sbtc-amount fak-ratio) TOTAL))
    (dex-amount (- sbtc-amount fak-amount))
    
    ;; Estimate outputs
    (token-from-fak (simulate-sbtc-to-token fak-amount))
    (stx-from-dex (if flag
                     (simulate-sbtc-to-stx dex-amount)
                     (simulate-sbtc-to-stx-velar dex-amount)))
    (token-from-dex (simulate-stx-to-token (* stx-from-dex u100)))
    
    ;; Total output
    (total-token-out (+ token-from-fak token-from-dex))
  )
    (ok {
      sbtc-amount: sbtc-amount,
      optimal-fak-ratio: fak-ratio,
      fak-amount: fak-amount,
      dex-amount: dex-amount,
      token-from-fak: token-from-fak,
      token-from-dex: token-from-dex,
      total-token-out: total-token-out
    })
  )
)

;; Read-only function to estimate optimal output for STX to B swap
(define-read-only (estimate-stx-to-token (stx-amount uint) (flag bool))
  (let (
    ;; Get optimal ratio
    (ratio-data (calculate-optimal-ratio-stx-to-token flag))
    (alex-ratio (get alex-ratio ratio-data))
    (dex-ratio (get dex-ratio ratio-data))
    
    ;; Calculate amounts for each route
    (alex-amount (/ (* stx-amount alex-ratio) u100))
    (dex-amount (- stx-amount alex-amount))
    
    ;; Estimate outputs
    (token-from-alex (simulate-stx-to-token (* alex-amount u100)))
    (sbtc-from-dex (if flag
                      (simulate-stx-to-sbtc dex-amount)
                      (simulate-stx-to-sbtc-velar dex-amount)))
    (token-from-dex (simulate-sbtc-to-token sbtc-from-dex))
    
    ;; Total output
    (total-token-out (+ token-from-alex token-from-dex))
  )
    (ok {
      stx-amount: stx-amount,
      optimal-alex-ratio: alex-ratio,
      alex-amount: alex-amount,
      dex-amount: dex-amount,
      token-from-alex: token-from-alex,
      token-from-dex: token-from-dex,
      total-token-out: total-token-out
    })
  )
)

;; Simulation/swap functions from your original contract
(define-private (swap-token-to-sbtc (token-amount uint))
  (let (
      (result (try! (contract-call? 
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory-pool
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
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory-pool
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
         'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01
         swap-y-for-x
         'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v2
         'SP1KK89R86W73SJE6RQNQPRDM471008S9JY4FQA62.token-wbfaktory
         u100000000
         token-amount
         none
       )))
     )
     (ok (get dx result))
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
    'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory-pool
    quote
    token-amount
    (some 0x01) 
  )))
)

(define-read-only (simulate-sbtc-to-token (sbtc-amount uint))
  (get dy (unwrap-panic (contract-call? 
    'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory-pool
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
     (let (
       (fee (/ (+ (* stx-amount u500000) u99999999) u100000000))
       (stx-net (if (<= stx-amount fee) u0 (- stx-amount fee)))
     )
     (unwrap-panic (contract-call?
       'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01
       get-y-given-x
       'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v2
       'SP1KK89R86W73SJE6RQNQPRDM471008S9JY4FQA62.token-wbfaktory
       u100000000
       stx-net
     ))
     )
   )

(define-read-only (simulate-token-to-stx (token-amount uint))
     (let (
       (fee (/ (+ (* token-amount u500000) u99999999) u100000000))
       (token-net (if (<= token-amount fee) u0 (- token-amount fee)))
     )
     (unwrap-panic (contract-call?
       'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01
       get-x-given-y
       'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v2
       'SP1KK89R86W73SJE6RQNQPRDM471008S9JY4FQA62.token-wbfaktory
       u100000000
       token-net
     ))
     )
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
(define-read-only (compare-sbtc-to-token-routes (sbtc-amount uint))
  (let (
    ;; Get estimates for different route combinations
    (route-bit (unwrap-panic (estimate-sbtc-to-token sbtc-amount true)))
    (route-vel (unwrap-panic (estimate-sbtc-to-token sbtc-amount false)))
    
    ;; Compare outputs
    (best-route (if (> (get total-token-out route-bit) (get total-token-out route-vel)) 
                   "BitFlow" 
                   "Velar"))
    (best-output (if (> (get total-token-out route-bit) (get total-token-out route-vel))
                    (get total-token-out route-bit)
                    (get total-token-out route-vel)))
    (best-fak-ratio (if (> (get total-token-out route-bit) (get total-token-out route-vel))
                       (get optimal-fak-ratio route-bit)
                       (get optimal-fak-ratio route-vel)))
  )
    {
      sbtc-amount: sbtc-amount,
      best-route: best-route,
      best-output: best-output,
      best-fak-ratio: best-fak-ratio,
      bit-output: (get total-token-out route-bit),
      vel-output: (get total-token-out route-vel),
      bit-fak-ratio: (get optimal-fak-ratio route-bit),
      vel-fak-ratio: (get optimal-fak-ratio route-vel)
    }
  )
)

(define-read-only (compare-stx-to-token-routes (stx-amount uint))
  (let (
    ;; Get estimates for different route combinations
    (route-bit (unwrap-panic (estimate-stx-to-token stx-amount true)))
    (route-vel (unwrap-panic (estimate-stx-to-token stx-amount false)))
    
    ;; Compare outputs
    (best-route (if (> (get total-token-out route-bit) (get total-token-out route-vel)) 
                   "BitFlow" 
                   "Velar"))
    (best-output (if (> (get total-token-out route-bit) (get total-token-out route-vel))
                    (get total-token-out route-bit)
                    (get total-token-out route-vel)))
    (best-alex-ratio (if (> (get total-token-out route-bit) (get total-token-out route-vel))
                         (get optimal-alex-ratio route-bit)
                         (get optimal-alex-ratio route-vel)))
  )
    {
      stx-amount: stx-amount,
      best-route: best-route,
      best-output: best-output,
      best-alex-ratio: best-alex-ratio,
      bit-output: (get total-token-out route-bit),
      vel-output: (get total-token-out route-vel),
      bit-alex-ratio: (get optimal-alex-ratio route-bit),
      vel-alex-ratio: (get optimal-alex-ratio route-vel)
    }
  )
)

;; Convenience functions that automatically use the best route and ratio
(define-public (smart-buy-with-sbtc
    (sbtc-amount uint)
    (min-token-out uint))
  (let (
    (best-route (compare-sbtc-to-token-routes sbtc-amount))
    (use-flag (is-eq (get best-route best-route) "BitFlow"))
    (fak-ratio (get best-fak-ratio best-route))
  )
    (try! (buy-with-sbtc sbtc-amount min-token-out fak-ratio use-flag))
    (ok {
      sbtc-amount: sbtc-amount,
      token-out: (get best-output best-route),
      route-used: (get best-route best-route),
      fak-ratio-used: fak-ratio
    })
  )
)

(define-public (smart-buy-with-stx
    (stx-amount uint)
    (min-token-out uint))
  (let (
    (best-route (compare-stx-to-token-routes stx-amount))
    (use-flag (is-eq (get best-route best-route) "BitFlow"))
    (alex-ratio (get best-alex-ratio best-route))
  )
    (try! (buy-with-stx stx-amount min-token-out alex-ratio use-flag))
    (ok {
      stx-amount: stx-amount,
      token-out: (get best-output best-route),
      route-used: (get best-route best-route),
      alex-ratio-used: alex-ratio
    })
  )
)

;; Similar read-only functions for selling B tokens
(define-read-only (estimate-token-to-sbtc (token-amount uint) (flag bool))
  (let (
    (ratio-data (calculate-optimal-ratio-sbtc-to-token flag))
    (fak-ratio (get fak-ratio ratio-data))
    (dex-ratio (get dex-ratio ratio-data))
    
    ;; Calculate amounts for each route
    (fak-amount (/ (* token-amount fak-ratio) TOTAL))
    (dex-amount (- token-amount fak-amount))
    
    ;; Estimate outputs
    (sbtc-from-fak (simulate-token-to-sbtc fak-amount))
    (stx-from-dex (simulate-token-to-stx dex-amount))
    (sbtc-from-dex (if flag
                     (simulate-stx-to-sbtc (/ stx-from-dex u100))
                     (simulate-stx-to-sbtc-velar (/ stx-from-dex u100))))
    
    ;; Total output
    (total-sbtc-out (+ sbtc-from-fak sbtc-from-dex))
  )
    (ok {
      token-amount: token-amount,
      optimal-fak-ratio: fak-ratio,
      fak-amount: fak-amount,
      dex-amount: dex-amount,
      sbtc-from-fak: sbtc-from-fak,
      sbtc-from-dex: sbtc-from-dex,
      total-sbtc-out: total-sbtc-out
    })
  )
)

(define-read-only (estimate-token-to-stx (token-amount uint) (flag bool))
  (let (
    ;; For sell routes, we need to invert the ratios from the buy routes
    (ratio-data (calculate-optimal-ratio-stx-to-token flag))
    (alex-ratio (get alex-ratio ratio-data))
    (dex-ratio (get dex-ratio ratio-data))
    
    ;; Calculate amounts for each route
    (alex-amount (/ (* token-amount alex-ratio) u100))
    (dex-amount (- token-amount alex-amount))
    
    ;; Estimate outputs
    (stx-from-alex (/ (simulate-token-to-stx alex-amount) u100))
    (sbtc-from-dex (simulate-token-to-sbtc dex-amount))
    (stx-from-dex (if flag
                      (simulate-sbtc-to-stx sbtc-from-dex)
                      (simulate-sbtc-to-stx-velar sbtc-from-dex)))
    
    ;; Total output
    (total-stx-out (+ stx-from-alex stx-from-dex))
  )
    (ok {
      token-amount: token-amount,
      optimal-alex-ratio: alex-ratio,
      alex-amount: alex-amount,
      dex-amount: dex-amount,
      stx-from-alex: stx-from-alex,
      stx-from-dex: stx-from-dex,
      total-stx-out: total-stx-out
    })
  )
)

(define-read-only (compare-token-to-sbtc-routes (token-amount uint))
  (let (
    ;; Get estimates for different route combinations
    (route-bit (unwrap-panic (estimate-token-to-sbtc token-amount true)))
    (route-vel (unwrap-panic (estimate-token-to-sbtc token-amount false)))
    
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
      token-amount: token-amount,
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

(define-read-only (compare-token-to-stx-routes (token-amount uint))
  (let (
    ;; Get estimates for different route combinations
    (route-bit (unwrap-panic (estimate-token-to-stx token-amount true)))
    (route-vel (unwrap-panic (estimate-token-to-stx token-amount false)))
    
    ;; Compare outputs
    (best-route (if (> (get total-stx-out route-bit) (get total-stx-out route-vel)) 
                   "BitFlow" 
                   "Velar"))
    (best-output (if (> (get total-stx-out route-bit) (get total-stx-out route-vel))
                    (get total-stx-out route-bit)
                    (get total-stx-out route-vel)))
    (best-alex-ratio (if (> (get total-stx-out route-bit) (get total-stx-out route-vel))
                         (get optimal-alex-ratio route-bit)
                         (get optimal-alex-ratio route-vel)))
  )
    {
      token-amount: token-amount,
      best-route: best-route,
      best-output: best-output,
      best-alex-ratio: best-alex-ratio,
      bit-output: (get total-stx-out route-bit),
      vel-output: (get total-stx-out route-vel),
      bit-alex-ratio: (get optimal-alex-ratio route-bit),
      vel-alex-ratio: (get optimal-alex-ratio route-vel)
    }
  )
)

;; Convenience functions for selling B with the best route and ratio
(define-public (smart-sell-for-sbtc
    (token-amount uint)
    (min-sbtc-out uint))
  (let (
    (best-route (compare-token-to-sbtc-routes token-amount))
    (use-flag (is-eq (get best-route best-route) "BitFlow"))
    (fak-ratio (get best-fak-ratio best-route))
  )
    (try! (sell-for-sbtc token-amount min-sbtc-out fak-ratio use-flag))
    (ok {
      token-amount: token-amount,
      sbtc-out: (get best-output best-route),
      route-used: (get best-route best-route),
      fak-ratio-used: fak-ratio
    })
  )
)

(define-public (smart-sell-for-stx
    (token-amount uint)
    (min-stx-out uint))
  (let (
    (best-route (compare-token-to-stx-routes token-amount))
    (use-flag (is-eq (get best-route best-route) "BitFlow"))
    (alex-ratio (get best-alex-ratio best-route))
  )
    (try! (sell-for-stx token-amount min-stx-out alex-ratio use-flag))
    (ok {
      token-amount: token-amount,
      stx-out: (get best-output best-route),
      route-used: (get best-route best-route),
      alex-ratio-used: alex-ratio
    })
  )
)