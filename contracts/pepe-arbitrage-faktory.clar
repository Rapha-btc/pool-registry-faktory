;; Arbitrage: PEPE -> sBTC -> STX -> PEPE
;; Uses: Charisma, Bitflow, Velar

(use-trait ft-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)
(use-trait pool-trait 'SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS.dexterity-traits-v0.liquidity-pool-trait)

(define-constant ERR-SLIPPAGE (err u1000))
(define-constant ERR-NO-PROFIT (err u1001))

;; Token addresses
(define-constant PEPE 'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz)
(define-constant SBTC 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token)
(define-constant WSTX 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx)

;; Pool addresses
(define-constant CHARISMA-POOL 'SP6SA6BTPNN5WDAWQ7GWJF1T5E2KWY01K9SZDBJQ.pepe-faktory-pool)
(define-constant VELAR-POOL-ID u3) ;; STX-PEPE pool ID on Velar

;; Main arb function: PEPE -> sBTC -> STX -> PEPE
(define-public (arb-sell-fak
    (pepe-in uint)
    (min-pepe-out uint))
  (begin
    ;; Step 1: PEPE -> sBTC via Charisma
    (let ((sbtc-out (try! (swap-pepe-to-sbtc pepe-in))))
      
      ;; Step 2: sBTC -> STX via Bitflow
      (let ((stx-out (try! (swap-sbtc-to-stx sbtc-out))))
        
        ;; Step 3: STX -> PEPE via Velar (direct pool call)
        (let ((pepe-out (try! (swap-stx-to-pepe stx-out))))
          
          ;; Verify profit
          (asserts! (>= pepe-out min-pepe-out) ERR-SLIPPAGE)
          (asserts! (> pepe-out pepe-in) ERR-NO-PROFIT)
          
          (ok {
            pepe-in: pepe-in,
            pepe-out: pepe-out,
            profit: (- pepe-out pepe-in)
          })
        )
      )
    )
  )
)

;; Step 1: PEPE -> sBTC via Charisma (through registry)
(define-private (swap-pepe-to-sbtc (pepe-amount uint))
  (let (
      (result (try! (contract-call? 
        'SP6SA6BTPNN5WDAWQ7GWJF1T5E2KWY01K9SZDBJQ.pepe-faktory-pool
        execute
        pepe-amount
        (some 0x01) ;; OP_SWAP_B_TO_A (PEPE is token B, sBTC is token A)
      )))
    )
    (ok (get dy result))
  )
)

;; Step 2: sBTC -> STX via Bitflow xyk pool
(define-private (swap-sbtc-to-stx (sbtc-amount uint))
  (let (
      (result (try! (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2
        swap-x-for-y
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1
        SBTC
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2
        sbtc-amount
        u1 ;; min-dy
      )))
    )
    (ok (get dy result))
  )
)

;; Step 3: STX -> PEPE via Velar (DIRECT pool call - faster!)
(define-private (swap-stx-to-pepe (stx-amount uint))
  (let (
      ;; First wrap STX to WSTX
      (wstx-amount (try! (contract-call?
        WSTX
        wrap
        stx-amount
      )))
      
      ;; Then swap WSTX -> PEPE directly through Velar pool
      (result (try! (contract-call?
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-router
        swap-exact-tokens-for-tokens
        VELAR-POOL-ID
        WSTX ;; token0
        PEPE ;; token1  
        WSTX ;; token-in
        PEPE ;; token-out
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to
        stx-amount
        u1 ;; min-amt-out
      )))
    )
    (ok (get amt-out result))
  )
)

;; Alternative Route 2: PEPE -> STX -> sBTC -> PEPE
(define-public (arb-sell-velar
    (pepe-in uint)
    (min-pepe-out uint))
  (let (
      ;; Step 1: PEPE -> STX via Velar
      (stx-out (try! (swap-pepe-to-stx pepe-in)))
      
      ;; Step 2: STX -> sBTC via Bitflow  
      (sbtc-out (try! (swap-stx-to-sbtc stx-out)))
      
      ;; Step 3: sBTC -> PEPE via Charisma
      (pepe-out (try! (swap-sbtc-to-pepe sbtc-out)))
    )
    (asserts! (>= pepe-out min-pepe-out) ERR-SLIPPAGE)
    (asserts! (> pepe-out pepe-in) ERR-NO-PROFIT)
    
    (ok {
      pepe-in: pepe-in,
      pepe-out: pepe-out,
      profit: (- pepe-out pepe-in)
    })
  )
)

;; Helper: PEPE -> STX via Velar
(define-private (swap-pepe-to-stx (pepe-amount uint))
  (let (
      (result (try! (contract-call?
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-router
        swap-exact-tokens-for-tokens
        VELAR-POOL-ID
        PEPE ;; token0
        WSTX ;; token1
        PEPE ;; token-in
        WSTX ;; token-out
        'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to
        pepe-amount
        u1
      )))
      ;; Unwrap WSTX to STX
      (stx-amount (try! (contract-call? WSTX unwrap (get amt-out result))))
    )
    (ok stx-amount)
  )
)

;; Helper: STX -> sBTC via Bitflow
(define-private (swap-stx-to-sbtc (stx-amount uint))
  (let (
      (result (try! (contract-call?
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2
        swap-y-for-x
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1
        SBTC
        'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2
        stx-amount
        u1
      )))
    )
    (ok (get dx result))
  )
)

;; Helper: sBTC -> PEPE via Charisma
(define-private (swap-sbtc-to-pepe (sbtc-amount uint))
  (let (
      (result (try! (contract-call?
        'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.faktory-core-v2
        execute
        CHARISMA-POOL
        sbtc-amount
        (some 0x00) ;; OP_SWAP_A_TO_B (sBTC is token A, PEPE is token B)
      )))
    )
    (ok (get dy result))
  )
)