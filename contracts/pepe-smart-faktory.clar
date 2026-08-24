;; SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.pepe-smart-faktory
;; DRAFT - modeled on mia-smart-faktory (deployed, Clarity 5). Differences:
;;   - token: Bitcoin PEPE (tokensoft-token-v4k68639zxz, asset "tokensoft-token")
;;   - fak leg: fakfun-core-v2.execute on pepe-faktory-pool-v2-2 (same pool the
;;     deployed pepe-arbitrage-faktory-v3 routes through)
;;   - STX-side DEX leg: no ALEX pool for PEPE, so `flag` picks a whole family:
;;       true  = BitFlow: xyk-pool-sbtc-stx (bridge) + xyk-pool-pepe-stx (PEPE=X, STX=Y)
;;       false = Velar:   univ2-pool-0070 (bridge)   + univ2 pool id 11 wstx/pepe via univ2-router
;;     Both venues quote and settle in native units, so none of mia-smart's
;;     8-dec ALEX scaling (* u100 / / u100) exists here.
;;   - fak sell leg shaves the 0.1% faktory fee off dy exactly as pepe-arb-v3 does

;; Naming note: the public interface (buy-with-stx alex-ratio, estimate-*
;; optimal-alex-ratio, compare-* best-alex-ratio, print keys *-from-alex) is kept
;; byte-for-byte from b-smart / mia-smart so the fak.fun and legacy front ends
;; and the poll-smart-swaps indexer treat this router as one more config entry.
;; Here "alex" simply means the STX-side DEX leg; there is no ALEX pool.

(define-constant ERR-SLIPPAGE (err u1000))
(define-constant ERR-NO-PROFIT (err u1001))
(define-constant ERR-INVALID-RATIO (err u1002))
(define-constant ERR-PARTIAL-FILL (err u1003))

;; Principals used more than once. Named so a wrong address is a compile error
;; in one place rather than a typo buried in the tenth call site. Read-only
;; simulate-* helpers keep their literals: those are quotes, not value moves.
(define-constant TOKEN 'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz)
(define-constant SBTC 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token)

;; FT asset identifiers for the with-ft allowances below. These are the names
;; declared by define-fungible-token in each token contract, NOT the contract
;; name: tokensoft-token-v4k68639zxz declares "tokensoft-token". Getting one wrong makes every
;; transfer under that allowance abort.
(define-constant TOKEN-ASSET "tokensoft-token")
(define-constant SBTC-ASSET "sbtc-token")

(define-constant CORE 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-core-v2)
(define-constant POOL 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.pepe-faktory-pool-v2-2)
(define-constant XYK-CORE 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2)
(define-constant XYK-POOL 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1)
(define-constant STX-TOKEN 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2)
(define-constant VELAR-POOL 'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070)
(define-constant VELAR-FEES 'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-fees-v1_0_0-0070)
(define-constant WSTX 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx)

(define-constant XYK-TOKEN-POOL 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-pepe-stx-v-1-1)
(define-constant VELAR-ROUTER 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-router)
(define-constant VELAR-CORE 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-core)
(define-constant VELAR-SHARE-FEE 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to)
;; Velar wstx/pepe pool id (reserve0 = wstx, reserve1 = pepe), from pepe-arb-v3.
(define-constant VELAR-TOKEN-POOL-ID u11)
(define-constant TOTAL u100)

(define-public (buy-with-sbtc
    (sbtc-amount uint)
    (min-token-out uint)
    (fak-ratio uint)
    (flag bool))
  (begin
    ;; Guard BEFORE the let: the bindings below underflow when the ratio
    ;; exceeds 100 (sbtc-amount - fak-amount goes negative), so an assert placed
    ;; after them never runs and the caller gets an opaque runtime abort
    ;; instead of ERR-INVALID-RATIO.
    (asserts! (<= fak-ratio TOTAL) ERR-INVALID-RATIO)
    (let (
    (fak-amount (/ (* sbtc-amount fak-ratio) TOTAL))
    (alex-amount (- sbtc-amount fak-amount))
    )

    (try! (contract-call?
      SBTC
      transfer
      sbtc-amount
      tx-sender
      current-contract
      none
    ))

    (let (
      (sender tx-sender)
      (token-from-fak (if (> fak-amount u0)
                      (try! (as-contract? ((with-ft SBTC SBTC-ASSET fak-amount)) (try! (swap-sbtc-to-token fak-amount))))
                      u0))

      (stx-from-dex (if (> alex-amount u0)
                        (if flag
                            (try! (as-contract? ((with-ft SBTC SBTC-ASSET alex-amount)) (try! (swap-sbtc-to-stx alex-amount))))
                            (try! (as-contract? ((with-ft SBTC SBTC-ASSET alex-amount)) (try! (swap-sbtc-to-stx-velar alex-amount)))))
                        u0))

      (token-from-alex (if (> stx-from-dex u0)
                      (try! (as-contract? ((with-stx stx-from-dex)) (try! (swap-stx-to-token stx-from-dex flag))))
                      u0))
      (total-token-out (+ token-from-fak token-from-alex)))

      (asserts! (>= total-token-out min-token-out) ERR-SLIPPAGE)

      (try! (as-contract? ((with-ft TOKEN TOKEN-ASSET total-token-out))
        (try! (contract-call? TOKEN transfer total-token-out current-contract sender none))
      ))

      (print {
        type: "buy",
        sender: tx-sender,
        token-in: SBTC,
        amount-in: sbtc-amount,
        token-out: TOKEN,
        amount-out: total-token-out,
        token-from-fak: token-from-fak,
        token-from-dex: token-from-alex,
        pool-contract: current-contract,
        min-y-out: min-token-out })
      (ok {
        sbtc-amount: sbtc-amount,
        token-from-fak: token-from-fak,
        token-from-dex: token-from-alex,
        total-token-out: total-token-out
      })
    )
  )
))

(define-public (buy-with-stx
    (stx-amount uint)
    (min-token-out uint)
    (alex-ratio uint)
    (flag bool))
  (begin
    ;; Guard BEFORE the let: the bindings below underflow when the ratio
    ;; exceeds 100 (stx-amount - alex-amount goes negative), so an assert placed
    ;; after them never runs and the caller gets an opaque runtime abort
    ;; instead of ERR-INVALID-RATIO.
    (asserts! (<= alex-ratio TOTAL) ERR-INVALID-RATIO)
    (let (
    (alex-amount (/ (* stx-amount alex-ratio) TOTAL))
    (fak-amount (- stx-amount alex-amount))
    )

    (try! (stx-transfer? stx-amount tx-sender current-contract))

    (let (
      (sender tx-sender)
      (token-from-alex (if (> alex-amount u0)
                      (try! (as-contract? ((with-stx alex-amount)) (try! (swap-stx-to-token alex-amount flag))))
                      u0))

      (sbtc-from-dex (if (> fak-amount u0)
                         (if flag
                             (try! (as-contract? ((with-stx fak-amount)) (try! (swap-stx-to-sbtc fak-amount))))
                             (try! (as-contract? ((with-stx fak-amount)) (try! (swap-stx-to-sbtc-velar fak-amount)))))
                         u0))
      (token-from-fak (if (> sbtc-from-dex u0)
                      (try! (as-contract? ((with-ft SBTC SBTC-ASSET sbtc-from-dex)) (try! (swap-sbtc-to-token sbtc-from-dex))))
                      u0))

      (total-token-out (+ token-from-alex token-from-fak))
    )
      (asserts! (>= total-token-out min-token-out) ERR-SLIPPAGE)

      (try! (as-contract? ((with-ft TOKEN TOKEN-ASSET total-token-out))
        (try! (contract-call? TOKEN transfer total-token-out current-contract sender none))
      ))
        (print {
        type: "buy",
        sender: tx-sender,
        token-in: 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx,
        amount-in: stx-amount,
        token-out: TOKEN,
        amount-out: total-token-out,
        token-from-alex: token-from-alex,
        token-from-dex: token-from-fak,
        pool-contract: current-contract,
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
))

(define-public (sell-for-sbtc
    (token-amount uint)
    (min-sbtc-out uint)
    (fak-ratio uint)
    (flag bool))
  (begin
    ;; Guard BEFORE the let: the bindings below underflow when the ratio
    ;; exceeds 100 (token-amount - fak-amount goes negative), so an assert placed
    ;; after them never runs and the caller gets an opaque runtime abort
    ;; instead of ERR-INVALID-RATIO.
    (asserts! (<= fak-ratio TOTAL) ERR-INVALID-RATIO)
    (let (
    (fak-amount (/ (* token-amount fak-ratio) TOTAL))
    (alex-amount (- token-amount fak-amount))
    )

    (try! (contract-call?
      TOKEN
      transfer
      token-amount
      tx-sender
      current-contract
      none
    ))

    (let (
      (sender tx-sender)
      (sbtc-from-fak (if (> fak-amount u0)
                         (try! (as-contract? ((with-ft TOKEN TOKEN-ASSET fak-amount)) (try! (swap-token-to-sbtc fak-amount))))
                         u0))

      (stx-from-alex (if (> alex-amount u0)
                        (try! (as-contract? ((with-ft TOKEN TOKEN-ASSET alex-amount)) (try! (swap-token-to-stx alex-amount flag))))
                        u0))
      (sbtc-from-dex (if (> stx-from-alex u0)
                         (if flag
                             (try! (as-contract? ((with-stx stx-from-alex)) (try! (swap-stx-to-sbtc stx-from-alex))))
                             (try! (as-contract? ((with-stx stx-from-alex)) (try! (swap-stx-to-sbtc-velar stx-from-alex)))))
                         u0))

      (total-sbtc-out (+ sbtc-from-fak sbtc-from-dex))
    )
      (asserts! (>= total-sbtc-out min-sbtc-out) ERR-SLIPPAGE)

      (try! (as-contract? ((with-ft SBTC SBTC-ASSET total-sbtc-out))
        (try! (contract-call? SBTC transfer total-sbtc-out current-contract sender none))
      ))
      (print {
        type: "sell",
        sender: tx-sender,
        token-in: TOKEN,
        amount-in: token-amount,
        token-out: SBTC,
        amount-out: total-sbtc-out,
        sbtc-from-fak: sbtc-from-fak,
        sbtc-from-dex: sbtc-from-dex,
        pool-contract: current-contract,
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
))

(define-public (sell-for-stx
    (token-amount uint)
    (min-stx-out uint)
    (alex-ratio uint)
    (flag bool))
  (begin
    ;; Guard BEFORE the let: the bindings below underflow when the ratio
    ;; exceeds 100 (token-amount - alex-amount goes negative), so an assert placed
    ;; after them never runs and the caller gets an opaque runtime abort
    ;; instead of ERR-INVALID-RATIO.
    (asserts! (<= alex-ratio TOTAL) ERR-INVALID-RATIO)
    (let (
    (alex-amount (/ (* token-amount alex-ratio) TOTAL))
    (fak-amount (- token-amount alex-amount))
    )

    (try! (contract-call?
      TOKEN
      transfer
      token-amount
      tx-sender
      current-contract
      none
    ))

    (let (
      (sender tx-sender)
      (stx-from-alex (if (> alex-amount u0)
                        (try! (as-contract? ((with-ft TOKEN TOKEN-ASSET alex-amount)) (try! (swap-token-to-stx alex-amount flag))))
                        u0))

      (sbtc-from-fak (if (> fak-amount u0)
                         (try! (as-contract? ((with-ft TOKEN TOKEN-ASSET fak-amount)) (try! (swap-token-to-sbtc fak-amount))))
                         u0))
      (stx-from-dex (if (> sbtc-from-fak u0)
                        (if flag
                            (try! (as-contract? ((with-ft SBTC SBTC-ASSET sbtc-from-fak)) (try! (swap-sbtc-to-stx sbtc-from-fak))))
                            (try! (as-contract? ((with-ft SBTC SBTC-ASSET sbtc-from-fak)) (try! (swap-sbtc-to-stx-velar sbtc-from-fak)))))
                        u0))

      (total-stx-out (+ stx-from-alex stx-from-dex))
    )
      (asserts! (>= total-stx-out min-stx-out) ERR-SLIPPAGE)

      (try! (as-contract? ((with-stx total-stx-out))
        (try! (stx-transfer? total-stx-out current-contract sender))
      ))
      (print {
        type: "sell",
        sender: tx-sender,
        token-in: TOKEN,
        amount-in: token-amount,
        token-out: 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx,
        amount-out: total-stx-out,
        stx-from-alex: stx-from-alex,
        stx-from-dex: stx-from-dex,
        pool-contract: current-contract,
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
))

(define-read-only (calculate-optimal-ratio-sbtc-to-token (flag bool))
  (let (
    (fak-sbtc-token-liquidity (get-fak-sbtc-token-liquidity))
    (alex-stx-token-liquidity (get-dex-stx-token-liquidity flag))
    (sbtc-stx-liquidity (if flag
                          (get-bit-sbtc-stx-liquidity)
                          (get-velar-sbtc-stx-liquidity)))

    (y-balance (get y-balance sbtc-stx-liquidity))
    (alex-stx-token-in-sbtc (if (> y-balance u0) (/ (* alex-stx-token-liquidity (get x-balance sbtc-stx-liquidity)) y-balance) u0))

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

(define-read-only (calculate-optimal-ratio-stx-to-token (flag bool))
  (let (
    (alex-stx-token-liquidity (get-dex-stx-token-liquidity flag))
    (fak-sbtc-token-liquidity (get-fak-sbtc-token-liquidity))
    (sbtc-stx-liquidity (if flag
                          (get-bit-sbtc-stx-liquidity)
                          (get-velar-sbtc-stx-liquidity)))

    (x-balance (get x-balance sbtc-stx-liquidity))
    (fak-sbtc-token-in-stx (if (> x-balance u0) (/ (* fak-sbtc-token-liquidity (get y-balance sbtc-stx-liquidity)) x-balance) u0))

    (total-liquidity (+ alex-stx-token-liquidity fak-sbtc-token-in-stx))
    (alex-percentage (if (> total-liquidity u0) (/ (* alex-stx-token-liquidity u100) total-liquidity) u0))
  )
    {
      alex-ratio: alex-percentage,
      dex-ratio: (- u100 alex-percentage),
      alex-liquidity: alex-stx-token-liquidity,
      dex-liquidity-stx-equiv: fak-sbtc-token-in-stx,
      total-liquidity-stx-equiv: total-liquidity
    }
  )
)

(define-read-only (get-fak-sbtc-token-liquidity)
  (let (
    (pool-data (contract-call?
      'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.pepe-faktory-pool-v2-2
      get-reserves-quote))
  )
    (get dx pool-data)
  )
)

;; STX sitting on the STX-side DEX's PEPE pool, native uSTX. BitFlow: y-balance
;; (STX=Y). Velar: reserve0 (wstx). This is what the split ratio weighs against
;; the fak pool's sBTC side.
(define-read-only (get-dex-stx-token-liquidity (flag bool))
  (if flag
    (get y-balance (unwrap-panic (contract-call?
      'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-pepe-stx-v-1-1
      get-pool)))
    (get reserve0 (unwrap-panic (contract-call?
      'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-core
      get-pool
      u11)))
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
      x-balance: (get x-balance pool),
      y-balance: (get y-balance pool)
    }
  )
)

(define-read-only (get-velar-sbtc-stx-liquidity)
  (let ((pool (unwrap-panic (contract-call?
        'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070
        get-pool)))
    )
    {
      x-balance: (get reserve1 pool),
      y-balance: (get reserve0 pool)
    }
  )
)

(define-read-only (estimate-sbtc-to-token (sbtc-amount uint) (flag bool))
  (let (
    (ratio-data (calculate-optimal-ratio-sbtc-to-token flag))
    (fak-ratio (get fak-ratio ratio-data))
    (dex-ratio (get dex-ratio ratio-data))

    (fak-amount (/ (* sbtc-amount fak-ratio) TOTAL))
    (dex-amount (- sbtc-amount fak-amount))

    (token-from-fak (simulate-sbtc-to-token fak-amount))
    (stx-from-dex (if flag
                     (simulate-sbtc-to-stx dex-amount)
                     (simulate-sbtc-to-stx-velar dex-amount)))
    (token-from-dex (simulate-stx-to-token stx-from-dex flag))

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

(define-read-only (estimate-stx-to-token (stx-amount uint) (flag bool))
  (let (
    (ratio-data (calculate-optimal-ratio-stx-to-token flag))
    (alex-ratio (get alex-ratio ratio-data))
    (dex-ratio (get dex-ratio ratio-data))

    (alex-amount (/ (* stx-amount alex-ratio) u100))
    (dex-amount (- stx-amount alex-amount))

    (token-from-alex (simulate-stx-to-token alex-amount flag))
    (sbtc-from-dex (if flag
                      (simulate-stx-to-sbtc dex-amount)
                      (simulate-stx-to-sbtc-velar dex-amount)))
    (token-from-dex (simulate-sbtc-to-token sbtc-from-dex))

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

(define-private (swap-token-to-sbtc (token-amount uint))
  (let (
      (result (try! (contract-call?
        CORE
        execute
        POOL
        token-amount
        (some 0x01)
      )))
      (raw-dy (get dy result))
    )
    ;; swap-b-to-a reports GROSS dy but pays out dy - 0.1% faktory fee
    ;; (FAKTORY_FEE u1000 / PRECISION u1000000, charged on the sBTC output)
    (ok (- raw-dy (/ raw-dy u1000)))
  )
)

(define-private (swap-sbtc-to-token (sbtc-amount uint))
  (let (
      (result (try! (contract-call?
        CORE
        execute
        POOL
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
        XYK-CORE
        swap-x-for-y
        XYK-POOL
        SBTC
        STX-TOKEN
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
        XYK-CORE
        swap-y-for-x
        XYK-POOL
        SBTC
        STX-TOKEN
        stx-amount
        u1
      )))
    )
    (ok dx)
  )
)

;; STX -> PEPE on the STX-side DEX. BitFlow xyk-pool-pepe-stx: PEPE=X, STX=Y, so
;; sending STX is swap-y-for-x. Velar: univ2-router over pool 11 (wstx -> pepe).
(define-private (swap-stx-to-token (stx-amount uint) (flag bool))
  (if flag
    (let (
        (dx (try! (contract-call?
          XYK-CORE
          swap-y-for-x
          XYK-TOKEN-POOL
          TOKEN
          STX-TOKEN
          stx-amount
          u1
        )))
      )
      (ok dx)
    )
    (let (
        (result (try! (contract-call?
          VELAR-ROUTER
          swap-exact-tokens-for-tokens
          VELAR-TOKEN-POOL-ID
          WSTX
          TOKEN
          WSTX
          TOKEN
          VELAR-SHARE-FEE
          stx-amount
          u1
        )))
      )
      (ok (get amt-out result))
    )
  )
)

;; PEPE -> STX. BitFlow: swap-x-for-y (send X=PEPE, get Y=STX). Velar: pool 11 pepe -> wstx.
(define-private (swap-token-to-stx (token-amount uint) (flag bool))
  (if flag
    (let (
        (dy (try! (contract-call?
          XYK-CORE
          swap-x-for-y
          XYK-TOKEN-POOL
          TOKEN
          STX-TOKEN
          token-amount
          u1
        )))
      )
      (ok dy)
    )
    (let (
        (result (try! (contract-call?
          VELAR-ROUTER
          swap-exact-tokens-for-tokens
          VELAR-TOKEN-POOL-ID
          WSTX
          TOKEN
          TOKEN
          WSTX
          VELAR-SHARE-FEE
          token-amount
          u1
        )))
      )
      (ok (get amt-out result))
    )
  )
)

(define-private (swap-sbtc-to-stx-velar (sbtc-amount uint))
  (let (
      (result (try! (contract-call?
        VELAR-POOL
        swap
        SBTC
        WSTX
        VELAR-FEES
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
        VELAR-POOL
        swap
        WSTX
        SBTC
        VELAR-FEES
        stx-amount
        u1
      )))
    )
    (ok (get amt-out result))
  )
)

(define-read-only (simulate-token-to-sbtc (token-amount uint))
  (let ((q (contract-call?
    'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.pepe-faktory-pool-v2-2
    get-swap-quote
    token-amount
    (some 0x01)
  )))
  ;; get-swap-quote (bare tuple) carries the fee field; `quote` does not.
  ;; net received = dy - output-side faktory fee
  (- (get dy q) (get fee q)))
)

(define-read-only (simulate-sbtc-to-token (sbtc-amount uint))
  (get dy (unwrap-panic (contract-call?
    'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.pepe-faktory-pool-v2-2
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

;; STX -> PEPE quote. BitFlow: y-side fees, then x out. Velar: pool 11 reserves
;; (r0 = wstx, r1 = pepe) with the pool's own swap-fee num/den.
(define-read-only (simulate-stx-to-token (stx-amount uint) (flag bool))
  (if flag
    (let (
        (pool (unwrap-panic (contract-call?
          'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-pepe-stx-v-1-1
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
    (let (
        (pool (unwrap-panic (contract-call?
          'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-core
          get-pool
          u11)))
        (r0 (get reserve0 pool))
        (r1 (get reserve1 pool))
        (swap-fee (get swap-fee pool))
        (amt-in-adjusted (/ (* stx-amount (get num swap-fee)) (get den swap-fee)))
        (amt-out (/ (* r1 amt-in-adjusted) (+ r0 amt-in-adjusted)))
      )
      amt-out
    )
  )
)

;; PEPE -> STX quote, same two venues the other way round.
(define-read-only (simulate-token-to-stx (token-amount uint) (flag bool))
  (if flag
    (let (
        (pool (unwrap-panic (contract-call?
          'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-pepe-stx-v-1-1
          get-pool
        )))
        (x-balance (get x-balance pool))
        (y-balance (get y-balance pool))
        (protocol-fee (get x-protocol-fee pool))
        (provider-fee (get x-provider-fee pool))
        (BPS u10000)
        (x-amount-fees-protocol (/ (* token-amount protocol-fee) BPS))
        (x-amount-fees-provider (/ (* token-amount provider-fee) BPS))
        (x-amount-fees-total (+ x-amount-fees-protocol x-amount-fees-provider))
        (dx (- token-amount x-amount-fees-total))
        (updated-x-balance (+ x-balance dx))
        (dy (/ (* y-balance dx) updated-x-balance))
      )
      dy
    )
    (let (
        (pool (unwrap-panic (contract-call?
          'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-core
          get-pool
          u11)))
        (r0 (get reserve0 pool))
        (r1 (get reserve1 pool))
        (swap-fee (get swap-fee pool))
        (amt-in-adjusted (/ (* token-amount (get num swap-fee)) (get den swap-fee)))
        (amt-out (/ (* r0 amt-in-adjusted) (+ r1 amt-in-adjusted)))
      )
      amt-out
    )
  )
)

(define-read-only (simulate-sbtc-to-stx-velar (sbtc-amount uint))
  (let ((pool (unwrap-panic (contract-call?
          'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070
          get-pool)))
        (r0 (get reserve0 pool))
        (r1 (get reserve1 pool))
        (amt-in-adjusted (/ (* sbtc-amount u997) u1000))
        (amt-out (/ (* r0 amt-in-adjusted) (+ r1 amt-in-adjusted)))
  )
  amt-out)
)

(define-read-only (simulate-stx-to-sbtc-velar (stx-amount uint))
  (let ((pool (unwrap-panic (contract-call?
          'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070
          get-pool)))
        (r0 (get reserve0 pool))
        (r1 (get reserve1 pool))
        (amt-in-adjusted (/ (* stx-amount u997) u1000))
        (amt-out (/ (* r1 amt-in-adjusted) (+ r0 amt-in-adjusted)))
  )
  amt-out)
)

(define-read-only (compare-sbtc-to-token-routes (sbtc-amount uint))
  (let (
    (route-bit (unwrap-panic (estimate-sbtc-to-token sbtc-amount true)))
    (route-vel (unwrap-panic (estimate-sbtc-to-token sbtc-amount false)))

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
    (route-bit (unwrap-panic (estimate-stx-to-token stx-amount true)))
    (route-vel (unwrap-panic (estimate-stx-to-token stx-amount false)))

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

(define-read-only (estimate-token-to-sbtc (token-amount uint) (flag bool))
  (let (
    (ratio-data (calculate-optimal-ratio-sbtc-to-token flag))
    (fak-ratio (get fak-ratio ratio-data))
    (dex-ratio (get dex-ratio ratio-data))

    (fak-amount (/ (* token-amount fak-ratio) TOTAL))
    (dex-amount (- token-amount fak-amount))

    (sbtc-from-fak (simulate-token-to-sbtc fak-amount))
    (stx-from-dex (simulate-token-to-stx dex-amount flag))
    (sbtc-from-dex (if flag
                     (simulate-stx-to-sbtc stx-from-dex)
                     (simulate-stx-to-sbtc-velar stx-from-dex)))

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
    (ratio-data (calculate-optimal-ratio-stx-to-token flag))
    (alex-ratio (get alex-ratio ratio-data))
    (dex-ratio (get dex-ratio ratio-data))

    (alex-amount (/ (* token-amount alex-ratio) u100))
    (dex-amount (- token-amount alex-amount))

    (stx-from-alex (simulate-token-to-stx alex-amount flag))
    (sbtc-from-dex (simulate-token-to-sbtc dex-amount))
    (stx-from-dex (if flag
                      (simulate-sbtc-to-stx sbtc-from-dex)
                      (simulate-sbtc-to-stx-velar sbtc-from-dex)))

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
    (route-bit (unwrap-panic (estimate-token-to-sbtc token-amount true)))
    (route-vel (unwrap-panic (estimate-token-to-sbtc token-amount false)))

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
    (route-bit (unwrap-panic (estimate-token-to-stx token-amount true)))
    (route-vel (unwrap-panic (estimate-token-to-stx token-amount false)))

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
