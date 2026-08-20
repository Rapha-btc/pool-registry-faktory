# mia-smart-faktory

Split-router for MIA: every buy/sell is divided across the Faktory pool
(`mia-pool-faktory`) and a DEX leg, so a large order eats less slippage than it
would on either venue alone. Modelled on the deployed `b-smart-faktory`, with
three differences called out in the contract header: the fak leg goes through
`fakfun-core-v2`, the ALEX leg is the direct `wstx-v2`/`wmia` pool, and MIA is
6-decimal so the wmia legs convert `* u100` in and `/ u100` out.

**Status: DEPLOYED** at `SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.mia-smart-faktory`
(Clarity 5). The on-chain bytes are identical to `contracts/d-mia-smart-faktory.clar`
(the comment-stripped, `clarinet format` deploy variant), which is in turn
**semantically identical** to `contracts/mia-smart-faktory.clar` — the source the
sims deploy and test. Clarity discards comments and insignificant whitespace at
parse time, so the tested behaviour is the deployed behaviour, verified by a
code-only byte compare.

---

## 1. Clarity 5 in-contract post-conditions

The contract originally used classic `as-contract`, which grants the callee
unrestricted access to everything the contract holds. That matters here more
than in most contracts: the swap legs hand control to **external DEX
contracts** (ALEX, Velar, bitflow, fakfun-core) while this contract is sitting
on sBTC, STX and MIA. A buggy or hostile pool could move any of it.

Every one of the 20 `as-contract` calls is now `as-contract?` with an explicit
allowance for the single asset that leg actually sends:

| Leg | Sends | Allowance |
|---|---|---|
| `swap-sbtc-to-token`, `swap-sbtc-to-stx(-velar)` | sBTC | `with-ft SBTC SBTC-ASSET <amount>` |
| `swap-token-to-sbtc`, `swap-token-to-stx` | MIA | `with-ft MIA MIA-ASSET <amount>` |
| `swap-stx-to-sbtc(-velar)`, `swap-stx-to-token` | native STX | `with-stx <amount>` |
| MIA payout to caller | MIA | `with-ft MIA MIA-ASSET total-token-out` |
| sBTC payout to caller | sBTC | `with-ft SBTC SBTC-ASSET total-sbtc-out` |
| STX payout to caller | native STX | `with-stx total-stx-out` |

Anything outside that declaration aborts the transaction. Allowances are
ceilings, so the failure mode is a revert, never a loss.

### Three things worth knowing before editing this

1. **`as-contract` is illegal inside `define-constant` from Clarity 4 on.**
   `(define-constant CONTRACT (as-contract tx-sender))` does not compile; the
   replacement is the `current-contract` keyword.
2. **`as-contract?` needs a double `try!`.** It wraps the body's response, so
   the inner call has to be unwrapped too:
   `(try! (as-contract? ((with-ft …)) (try! (swap-… amount))))`. A single
   `try!` fails analysis with *"intermediary responses in consecutive
   statements must be checked"*.
3. **The FT asset name is not the contract name.** `miamicoin-token-v2`
   declares `(define-fungible-token miamicoin)`, so the allowance name is
   `"miamicoin"`. A wrong name makes every transfer under it abort.

### The ALEX decimal trap

`swap-stx-to-token` takes an **8-decimal** argument (callers pass
`(* amount u100)`) because ALEX's `amm-pool-v2-01` works in 8-dec fixed point
with `factor u100000000`. The **native STX that actually leaves the contract**
is the 6-decimal figure, so the allowance is the caller's `alex-amount`, not
the scaled value. Sim leg `buy-with-stx ratio=100` (pure ALEX) is what proves
this: it returns `(ok …)` rather than an allowance abort.

## 2. Manifest

Added to `Clarinet.toml` at `clarity_version = 5` — the rest of the project is
on Clarity 3, where `as-contract?` does not exist. Its 12 mainnet dependencies
(fak pool, ALEX wstx/wmia, bitflow xyk, velar univ2, MIA, sBTC) are declared as
`[[project.requirements]]`.

`clarinet check` → **5 contracts checked, 0 errors.**

## 3. Mainnet-fork simulation

`verify-mia-smart.js` is self-verifying: it pulls every result back and asserts
it, so a regression is a non-zero exit rather than something to spot by eye.
(`simul-b-smart.js`, the b-smart equivalent, only prints.)

```bash
node verify-mia-smart.js
```

**Result: [50/50 green](https://stxer.xyz/simulations/mainnet/1a822d1c3d08561916e9c5632a72119b)** (2026-08-20), Clarity 5 deploy included.

| Group | Cases | Covers |
|---|---|---|
| Read-only surface | 16 | 4 liquidity readers, 4 optimal-ratio calculators, 4 estimators, 4 route comparators |
| `buy-with-sbtc` | 6 | ratio 0 / 50 / 100 x bitflow / velar |
| `buy-with-stx` | 6 | same matrix |
| `sell-for-sbtc` | 6 | same matrix |
| `sell-for-stx` | 6 | same matrix |
| `smart-*` wrappers | 4 | contract picks ratio and venue itself |
| `*-dlmm` bridge | 5 | four DLMM routes at ratio 50 pool v-2, plus one at pool v-1 |

Ratios 0 and 100 are the single-venue extremes; **50 is the one that matters
most** for the allowance work, since both legs fire in one transaction and each
needs its own allowance to hold.

Impersonated principals: sBTC `SP2C7BCAP…QN2`, STX `SP9BP4PN…V51`, MIA
`SP3HXJJMJ…PZJ` (1.64B MIA).

### Observed on the fork

- Route comparators disagree by direction: Velar wins sBTC→MIA and STX→MIA,
  BitFlow wins MIA→STX. The `smart-*` wrappers pick accordingly.
- Optimal ratios land near an even split (45/55 sBTC, 54/46 STX), which is what
  you would expect with fak and DEX liquidity in the same order of magnitude.
- `sell-for-sbtc` on 100 MIA returns 31-33 **sats**. Correct for the size, but
  small enough that integer truncation dominates - do not read a ratio
  comparison at that scale as signal.

## 4. Error paths and the allowance-binding proof

`verify-mia-smart-negatives.js` covers what the happy-path run cannot.

```bash
node verify-mia-smart-negatives.js
```

**Result: [12/12 green](https://stxer.xyz/simulations/mainnet/998f95322760d6e799a133a05f2bee2e)** (2026-08-20).

| Case | Expected |
|---|---|
| `ratio = 101` on all four entry points | `ERR-INVALID-RATIO` (u1002) |
| `min-out = 1e30` on all four | `ERR-SLIPPAGE` (u1000) |
| Under-declared allowance | tx aborts |
| Same call, correct allowance | `(ok …)` |

The last two are the point. A harness that only shows correct allowances stay
out of the way cannot show they do anything, so this deploys a **sabotaged
twin** identical except that one leg's allowance is a single sat short of what
it sends. That transaction aborts (`err u0`, allowance violation) while the
control succeeds - so the allowances are demonstrably load-bearing rather than
decorative.

### Bug found and fixed: ERR-INVALID-RATIO was unreachable

The negative run first came back `(err none)` instead of `u1002` on all four
functions. Cause:

```clarity
(let (
  (fak-amount (/ (* sbtc-amount fak-ratio) TOTAL))   ;; ratio 101 -> 101000
  (alex-amount (- sbtc-amount fak-amount))            ;; 100000 - 101000 -> UNDERFLOW
)
  (asserts! (<= fak-ratio TOTAL) ERR-INVALID-RATIO)   ;; never reached
```

`let` bindings evaluate before the body, so any ratio above 100 underflowed and
panicked before the guard could run. Callers got an opaque runtime abort with
no error code. The guard is now hoisted above the `let` in all four functions,
and the same run returns a clean `u1002`.

**`b-smart-faktory` is deployed with this same structure** - worth checking
whether it shares the defect. It is not exploitable (the transaction still
fails, no funds move) but it is an unreadable failure for anyone integrating.

### Dead code

`ERR-NO-PROFIT` (u1001) is declared and never used anywhere in the contract.
Either wire it up or drop it.

## 5. Named-constant hoist

The venue callees and their trait/token args in the **private** swap legs
(`fakfun-core-v2`, `xyk-core-v-1-2`, `amm-pool-v2-01`, `univ2-pool`, plus the
pool/token principals) are now named constants — one definition per principal, so
a wrong address is a compile error in one place rather than a typo buried in the
tenth call site. `MIA`/`SBTC`/`MIA-ASSET`/`SBTC-ASSET`/`CONTRACT` were already
constants.

The read-only `simulate-*` / `get-*-liquidity` callees **keep their literals** —
this is not stylistic. A `contract-call?` in a `define-read-only` needs a literal
callee for the analyzer to prove the called function is itself read-only; a
constant callee fails deploy with *"expecting read-only statements, detected a
writing operation"*. `clarinet check` does **not** catch this — it passed a
full-constant version that the node rejected at deploy. The rule was found only
by running the stxer sim with the deploy step included, which is why every
constant change here is re-verified on the fork, not just checked.

## 6. DLMM bridge (additive)

The BitFlow/Velar router above is untouched. Four dedicated functions —
`buy-with-{sbtc,stx}-dlmm`, `sell-for-{sbtc,stx}-dlmm` — route the sBTC↔STX
middle leg through **Bitflow DLMM** instead. DLMM's concentrated liquidity prices
that leg tighter, so more of the Faktory-vs-ALEX gap survives the crossing. On
the fork, `sell-for-stx` at ratio 50 returned **186,889 STX via DLMM vs 161,355
BitFlow / 156,237 Velar** — the same split, ~16% more out.

- **Three pool versions** selectable via a `dlmm-pool` arg (`u1`/`u2`/`u3` →
  `dlmm-pool-stx-sbtc-v-N-bps-15`). A bin-exhaustion partial fill reverts
  `ERR-PARTIAL-FILL` (u1003) rather than stranding funds.
- **Off-chain priced.** DLMM has no read-only quote (bin walk), so it is *not* in
  the on-chain `compare-*` routers. The FE/keeper prices DLMM off-chain and calls
  these variants directly; `min-out` is the slippage guard. This is deliberate:
  the smart router does on-chain best-execution across BitFlow/Velar only, and the
  arb keeper (`mia-arbitrage-faktory`) handles DLMM where off-chain comparison
  belongs.

## 7. Invariant + edge coverage

`verify-mia-smart-coverage.js` asserts what the two suites above cannot — the
happy-path run only checks each call returns `(ok …)`; it never checks the
contract holds nothing afterward, or that the user actually received what the
function claimed.

```bash
node verify-mia-smart-coverage.js
```

**Result: [28/28 green](https://stxer.xyz/simulations/mainnet/57ddf06a07c87040870d4143e17ff210)** (2026-08-20), Clarity 5 deploy included.

| Scenario | Asserts |
|---|---|
| S1 buy conservation + payout | user MIA delta **==** returned `total-token-out`; contract holds **0** MIA/sBTC/STX after |
| S2 sell conservation + payout | user sBTC delta **==** returned `total-sbtc-out`; contract holds 0 |
| S3 DLMM ratio extremes | ratio 0 (full bridge) and 100 (all Faktory) on all four `*-dlmm` fns; contract holds 0 after |
| S4 DLMM negatives | ratio 101 → `ERR-INVALID-RATIO` (u1002); huge `min-out` → `ERR-SLIPPAGE` (u1000) |
| S5 `ERR-PARTIAL-FILL` | a 20k-sat sBTC→STX bridge on the thin v-3 pool (~20 STX) can't fill → guard reverts `u1003`, contract holds 0 — funds protected |
| S6 3-pool dispatch | a 2k-sat bridge fits v-3 → `(ok …)`, proving the selector reaches all three versions |

Block advances between scenario groups keep each under the per-block execution
cost cap — DLMM bin-walks are compute-heavy and a single block overflows.

**Conservation is the load-bearing check.** Every path pulls funds in, swaps
through external venues, and pays out — and after each, the contract's MIA, sBTC
and STX balances read exactly `u0`. Combined with the payout-delta check (the
user receives precisely the returned figure) and the allowance-abort proof from
§4, nothing leaks and nothing is stranded, on success or on revert.

### Live-state notes (not bugs)

The DLMM pools move: at test time v-2 held 1.58 BTC / 412k STX and v-3 was nearly
empty (~20 STX). The partial-fill guard only fires when a bridge genuinely exceeds
available bin depth — which is exactly the intended safety behaviour. Before
relying on a DLMM route in production, re-check which pool version is liquid
(Bitflow is mid-migration across v-1/v-2/v-3).

## 8. Remaining coverage gaps

- **Size sweep.** One amount per direction on the AMM legs. Slippage and the
  optimal-ratio maths are size-dependent, and dust-scale sells (31 sats on 100
  MIA) sit where integer truncation dominates.
- **Property fuzzing (next).** No Rendezvous target yet. The invariant worth
  writing first: *total-out is never worse than the better single-venue route* —
  that is the entire premise of splitting, and nothing currently tests it. RV in
  simnet needs the external venues mocked (the swap legs call mainnet pools that
  simnet doesn't have), the same pattern used for the vault's testable twin.
- **Adversarial pool.** No test with a hostile DEX callee. The allowances are
  what bound that blast radius, and the sabotaged-twin case is the closest
  proxy so far.
