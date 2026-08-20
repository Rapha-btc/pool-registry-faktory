# mia-smart-faktory

Split-router for MIA: every buy/sell is divided across the Faktory pool
(`mia-pool-faktory`) and a DEX leg, so a large order eats less slippage than it
would on either venue alone. Modelled on the deployed `b-smart-faktory`, with
three differences called out in the contract header: the fak leg goes through
`fakfun-core-v2`, the ALEX leg is the direct `wstx-v2`/`wmia` pool, and MIA is
6-decimal so the wmia legs convert `* u100` in and `/ u100` out.

**Status: not deployed.** `SPV9K21….mia-smart-faktory` is 404 on mainnet.

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

**Result: [45/45 green](https://stxer.xyz/simulations/mainnet/161fad64b90a488d0de47dd802ae40f9)** (2026-08-20).

| Group | Cases | Covers |
|---|---|---|
| Read-only surface | 16 | 4 liquidity readers, 4 optimal-ratio calculators, 4 estimators, 4 route comparators |
| `buy-with-sbtc` | 6 | ratio 0 / 50 / 100 x bitflow / velar |
| `buy-with-stx` | 6 | same matrix |
| `sell-for-sbtc` | 6 | same matrix |
| `sell-for-stx` | 6 | same matrix |
| `smart-*` wrappers | 4 | contract picks ratio and venue itself |

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

## 4. Coverage gaps

Happy paths are covered. Not yet:

- **Error paths.** `ERR-INVALID-RATIO` (u1002, ratio > 100), `ERR-SLIPPAGE`
  (u1000, `min-out` above what the split returns), `ERR-NO-PROFIT` (u1001).
- **Allowance negatives.** No test yet proves an allowance *binds* - i.e. that
  a deliberately under-declared allowance aborts. Today the sims only show the
  correct ones do not get in the way.
- **Size sweep.** One amount per direction. Slippage behaviour and the
  optimal-ratio maths are size-dependent, and dust-scale sells (31 sats) sit
  where truncation dominates.
- **Property fuzzing.** No Rendezvous target. The invariant worth writing
  first: *total-out is never less than the better single-venue route* - that is
  the entire premise of splitting.
