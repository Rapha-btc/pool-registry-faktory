(use-trait ft-trait .sip-010-trait.sip-010-trait)
(define-public (swap-x-for-y-simple-multi (pool principal) (tx <ft-trait>) (ty <ft-trait>) (amount uint) (min uint) (deadline (optional uint))) (begin (asserts! true (err u0)) (ok {in: amount, out: u1})))
(define-public (swap-y-for-x-simple-multi (pool principal) (tx <ft-trait>) (ty <ft-trait>) (amount uint) (min uint) (deadline (optional uint))) (begin (asserts! true (err u0)) (ok {in: amount, out: u1})))
