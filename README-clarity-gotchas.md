# Clarity gotchas worth knowing

Things that cost real debugging time in this repo. Each one is benign in the
sense that no funds are at risk - they are correctness and diagnostics traps,
which is exactly why they survive review.

---

## 1. `let` bindings run BEFORE the `asserts!` below them

The trap that made `ERR-INVALID-RATIO` unreachable in `mia-smart-faktory`.

```clarity
(let (
  (fak-amount (/ (* amount fak-ratio) TOTAL))
  (alex-amount (- amount fak-amount))          ;; ratio 101 -> goes negative
)
  (asserts! (<= fak-ratio TOTAL) ERR-INVALID-RATIO)   ;; never runs
```

Clarity evaluates every `let` binding first, then the body. With
`fak-ratio = 101`, `fak-amount` exceeds `amount`, so `(- amount fak-amount)`
underflows - and uints cannot go below zero, so the runtime aborts on the spot.
The guard sitting one line below never executes.

**"Unreachable" means the error code is declared but can never be returned.**
The caller gets a cryptic runtime abort instead of the clean `u1002` that says
"your ratio was invalid". Nothing is stolen and no funds move: the transaction
fails either way. The damage is purely diagnostic - an integrator cannot tell
what they did wrong, and your documented error code is a lie.

**Fix: guard before the maths.**

```clarity
(begin
  (asserts! (<= fak-ratio TOTAL) ERR-INVALID-RATIO)
  (let (
    (fak-amount (/ (* amount fak-ratio) TOTAL))
    (alex-amount (- amount fak-amount))
  )
    ...))
```

**How to catch it:** only negative testing finds this. Every happy-path test
passes a sane ratio, so the guard is never exercised and its unreachability is
invisible. `verify-mia-smart-negatives.js` caught it by asserting the *error
code*, not just that the call failed - `(err none)` and `(err u1002)` are both
"failures", and only one of them is correct.

**Status:** fixed in source and in the deployed `mia-smart-faktory`. Worth
checking any contract in this family that shares the `let`-then-`asserts!`
shape.

---

## 2. `as-contract` is illegal inside `define-constant` from Clarity 4 on

```clarity
(define-constant CONTRACT (as-contract tx-sender))   ;; Clarity 3 only
(define-constant CONTRACT current-contract)          ;; Clarity 4+
```

The old idiom fails analysis with *"use of unresolved function 'as-contract'"*,
which is a confusing message for something that plainly exists - it is the
*context* that is disallowed, not the function.

---

## 3. `as-contract?` needs a double `try!`

The Clarity 5 allowance form wraps the body's response, so the inner call has
to be unwrapped too:

```clarity
;; wrong - fails with "intermediary responses in consecutive statements
;; must be checked"
(try! (as-contract? ((with-ft SBTC "sbtc-token" amt)) (swap-sbtc-to-token amt)))

;; right
(try! (as-contract? ((with-ft SBTC "sbtc-token" amt))
  (try! (swap-sbtc-to-token amt))))
```

Note also that the allowances are a **list**: `((with-ft ...))`, not
`(with-ft ...)`.

---

## 4. The FT asset name is not the contract name

`with-ft` and post-conditions take the identifier from
`define-fungible-token`, which frequently differs from the contract name:

| Contract | Asset name |
|---|---|
| `miamicoin-token-v2` | `miamicoin` |
| `sbtc-token` | `sbtc-token` |

Get it wrong and the allowance names an asset that never moves, so the transfer
it was meant to permit aborts. Read it off the deployed interface rather than
guessing:

```bash
curl -s https://api.hiro.so/v2/contracts/interface/<addr>/<name> \
  | python3 -c "import json,sys; print([t['name'] for t in json.load(sys.stdin)['fungible_tokens']])"
```

The same trap exists in the frontend: an `assetName` that falls back to
`contractName.split(".")[1]` is right for Faktory-minted tokens and wrong for
anything pre-existing.

---

## 5. ALEX legs are 8-decimal, native STX is 6

`amm-pool-v2-01` works in 8-dec fixed point (`factor u100000000`), so callers
pass `(* amount u100)` and divide results by 100. But the **native STX that
actually leaves the contract is the 6-dec figure**, so a `with-stx` allowance
on an ALEX leg takes the unscaled amount:

```clarity
(as-contract? ((with-stx alex-amount))            ;; 6-dec, what really moves
  (try! (swap-stx-to-token (* alex-amount u100))))  ;; 8-dec, what ALEX wants
```

Scaling the allowance too would be 100x over-permissive; using the scaled value
where the unscaled is needed aborts the leg. `buy-with-stx` at `ratio = 100`
(pure ALEX) is the test that settles it.

---

## 6. Read-only calls can exceed a node's cost limit

Not a contract bug, but it presents as one. A node caps read-only execution via
`[connection_options]` in `config.toml`; the defaults are
`read_only_call_limit_read_length = 100000` and `read_only_call_limit_read_count = 30`.

`compare-sbtc-to-token-routes` quotes four venues in a single read and lands
around **213k read_length / 78 read_count**, so it returns
`RuntimeCheck(CostBalanceExceeded)` on a default-configured node while Hiro -
which runs far higher limits - answers it fine. In the fak.fun UI that
surfaced as *"Failed to determine best route"*, disabling smart buy for both
`b-smart-faktory` and `mia-smart-faktory`.

Two independent fixes, both applied: raise the limits on our own node, and have
the backend read proxy fall through to Hiro when the primary refuses. A cost
rejection is **HTTP 200 with `okay: false`**, so a fallback that only checks
`response.ok` will not trigger.
