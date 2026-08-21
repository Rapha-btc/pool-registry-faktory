(use-trait ft-trait .sip-010-trait.sip-010-trait)
(define-public (swap (tx <ft-trait>) (ty <ft-trait>) (fees principal) (amount uint) (min uint)) (begin (asserts! true (err u0)) (ok {amt-out: u1})))
(define-read-only (get-pool) (ok {reserve0: u1000000, reserve1: u1000000}))
