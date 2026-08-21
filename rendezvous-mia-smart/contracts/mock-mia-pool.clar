(define-read-only (get-swap-quote (amount uint) (opcode (optional (buff 16)))) {dx: u1, dy: u1, dk: u0, fee: u0})
(define-read-only (quote (amount uint) (opcode (optional (buff 16)))) (ok {dx: u1, dy: u1, dk: u0}))
(define-read-only (get-reserves-quote) {dx: u1, dy: u1, dk: u1})
