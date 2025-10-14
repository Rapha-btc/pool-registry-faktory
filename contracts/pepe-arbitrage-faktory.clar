;; Arbitrage: PEPE -> sBTC -> STX -> PEPE
;; Uses: Fakfun, Bitflow, Velar

(define-constant ERR-SLIPPAGE (err u1000))
(define-constant ERR-NO-PROFIT (err u1001))

(define-constant CONTRACT (as-contract tx-sender))
(define-constant SAINT 'SP000000000000000000002Q6VF78)

(define-constant VELAR-POOL-ID u11)

;; PEPE -> sBTC -> STX -> PEPE
(define-public (arb-sell-fak
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
          (pepe-out (try! (as-contract (swap-stx-to-pepe stx-out))))
          (pepe-arbitrager tx-sender)
          (burnt-pepe (- pepe-out pepe-in)))
          (asserts! (>= pepe-out min-pepe-out) ERR-SLIPPAGE)
          (asserts! (> pepe-out pepe-in) ERR-NO-PROFIT)
          (try! (as-contract (contract-call? 
            'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz 
            transfer 
            pepe-in 
            CONTRACT 
            pepe-arbitrager
            none
          )))
          (try! (as-contract (contract-call? 
            'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz 
            transfer 
            burnt-pepe 
            CONTRACT 
            SAINT
            none
          )))
          (ok {
            pepe-in: pepe-in,
            pepe-out: pepe-out,
            burnt-pepe: burnt-pepe
          })
        )
      )
    )

(define-private (swap-pepe-to-sbtc (pepe-amount uint))
  (let (
      (result (try! (contract-call? 
        'SP6SA6BTPNN5WDAWQ7GWJF1T5E2KWY01K9SZDBJQ.pepe-faktory-pool
        execute
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

;; Step 3: STX -> PEPE via Velar
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

;; Alternative Route: PEPE -> STX -> sBTC -> PEPE
;; (define-public (arb-sell-velar
;;     (pepe-in uint)
;;     (min-pepe-out uint))
;;   (begin
;;     ;; Step 1: Transfer PEPE from user to contract
;;     (try! (contract-call? 
;;       'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz 
;;       transfer 
;;       pepe-in 
;;       tx-sender 
;;       (as-contract tx-sender) 
;;       none
;;     ))
    
;;     ;; Step 2: PEPE -> STX via Velar (as-contract)
;;     (let ((stx-out (try! (as-contract (swap-pepe-to-stx pepe-in)))))
      
;;       ;; Step 3: STX -> sBTC via Bitflow (as-contract)
;;       (let ((sbtc-out (try! (as-contract (swap-stx-to-sbtc stx-out)))))
        
;;         ;; Step 4: sBTC -> PEPE via Charisma (as-contract)
;;         (let ((pepe-out (try! (as-contract (swap-sbtc-to-pepe sbtc-out)))))
          
;;           ;; Verify profit
;;           (asserts! (>= pepe-out min-pepe-out) ERR-SLIPPAGE)
;;           (asserts! (> pepe-out pepe-in) ERR-NO-PROFIT)
          
;;           ;; Transfer all PEPE back to user
;;           (try! (as-contract (contract-call? 
;;             'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz 
;;             transfer 
;;             pepe-out 
;;             tx-sender 
;;             contract-caller 
;;             none
;;           )))
          
;;           (ok {
;;             pepe-in: pepe-in,
;;             pepe-out: pepe-out,
;;             profit: (- pepe-out pepe-in)
;;           })
;;         )
;;       )
;;     )
;;   )
;; )

;; Helper: PEPE -> STX via Velar
;; (define-private (swap-pepe-to-stx (pepe-amount uint))
;;   (let (
;;       (result (try! (contract-call?
;;         'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-router
;;         swap-exact-tokens-for-tokens
;;         VELAR-POOL-ID
;;         'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
;;         'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx
;;         'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz
;;         'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx
;;         'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to
;;         pepe-amount
;;         u1
;;       )))
;;     )
;;     (ok (get amt-out result))
;;   )
;; )

;; ;; Helper: STX -> sBTC via Bitflow
;; (define-private (swap-stx-to-sbtc (stx-amount uint))
;;   (let (
;;       (result (try! (contract-call?
;;         'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2
;;         swap-y-for-x
;;         'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1
;;         'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
;;         'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2
;;         stx-amount
;;         u1
;;       )))
;;     )
;;     (ok (get dx result))
;;   )
;; )

;; ;; Helper: sBTC -> PEPE via Charisma
;; (define-private (swap-sbtc-to-pepe (sbtc-amount uint))
;;   (let (
;;       (result (try! (contract-call?
;;         'SP6SA6BTPNN5WDAWQ7GWJF1T5E2KWY01K9SZDBJQ.pepe-faktory-pool
;;         execute
;;         sbtc-amount
;;         (some 0x00) ;; OP_SWAP_A_TO_B (sBTC to PEPE)
;;       )))
;;     )
;;     (ok (get dy result))
;;   )
;; )