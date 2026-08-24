# pepe-smart-faktory

**Status: DEPLOYED 2026-08-24** at `SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.pepe-smart-faktory`
(txid `378482de3a3479d88135be8ba2f15e886b4c2e6a0d708d58e32879284eb01b07`), via faktory-dao `/api/bot/deploy-contract`. On-chain bytes = `contracts/d-pepe-smart-faktory.clar`.

Split-router for Bitcoin PEPE, modeled on the deployed `mia-smart-faktory`
(Clarity 5, `as-contract?` allowances). Same public interface as `b-smart` /
`mia-smart` - function names, arguments, tuple keys and print shape are
identical - so fak.fun `PoolTradingPanel` `SMART_TOKENS` and faktory-dao
`server/utils/smart-routers.ts` take it as one more config entry.

## Venues

| Leg | Venue |
|---|---|
| sBTC <-> PEPE (fak) | `fakfun-core-v2.execute` on `pepe-faktory-pool-v2-2` (0x00 buy, 0x01 sell; sell shaves the 0.1% faktory fee off dy, as `pepe-arbitrage-faktory-v3` does) |
| sBTC <-> STX bridge | `flag = true` BitFlow `xyk-pool-sbtc-stx-v-1-1`; `flag = false` Velar `univ2-pool-v1_0_0-0070` |
| STX <-> PEPE | `flag = true` BitFlow `xyk-pool-pepe-stx-v-1-1` (PEPE = X, STX = Y); `flag = false` Velar pool id 11 (wstx/pepe) via `univ2-router` |

`flag` therefore picks a whole DEX family. There is no ALEX pool for PEPE, so
none of mia-smart's 8-dec `* u100` / `/ u100` scaling exists here; every venue
quotes and settles in native units. The `alex-*` names in the interface are
kept only for FE/BE compatibility and mean "the STX-side DEX leg".

Asset name for the `with-ft` allowance: `tokensoft-token`
(`SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz`).

## Status

- `clarinet check`: compiles (2026-08-24). Warnings are the `unwrap-panic`
  quotes, same as mia-smart.
- stxer mainnet fork, 2026-08-24, block 8833457: `node verify-pepe-smart.js` ->
  **50/50 checks green** (https://stxer.xyz/simulations/mainnet/8d6a0cce124bbe7780516f6738113271).
  Deploy as Clarity 5, all 16 read-onlys, 24 core legs (4 fns x 2 flags x
  ratio 0/50/100), 4 smart-* wrappers. holder SP2022PJ05WB4VXP8HTVFAFE186AM94A4WYQ1RQY2 (710k PEPE), 100k PEPE per sell; smart-buy picked Velar at fak-ratio 62, smart-sell picked BitFlow at 69.
- Deployed (see top). Next: `SMART_ROUTERS` (backend) and `SMART_TOKENS` (fak.fun +
  legacy) with `assetName: "tokensoft-token"`.

- Negatives `node verify-pepe-smart-negatives.js` -> **12/12**: ratio 101 -> ERR-INVALID-RATIO on all four
  entry points, min-out 1e30 -> ERR-SLIPPAGE, and an under-declared allowance twin aborts while the
  correct contract succeeds (https://stxer.xyz/simulations/mainnet/797142e3b5fe76ca33867a24ce9b3c16).
- Zero residue: after every trade the router holds u0 STX / sBTC / PEPE (in the happy harness, 53/53:
  https://stxer.xyz/simulations/mainnet/75edd57da9a208a9c0a8396023786b15).
- Deploy variant `contracts/d-pepe-smart-faktory.clar` (comment-stripped, `clarinet format`) runs the
  same harness 53/53 (https://stxer.xyz/simulations/mainnet/9ecb60128738a63801cbe741b57b8bae) and is
  embedded byte-for-byte in faktory-dao `server/utils/pepe-smart-faktory-template.ts`, allowlisted as
  `pepe-smart-faktory` in `/api/bot/deploy-contract` (Clarity 5, account 0, fee 0.1 STX).

## What the sims prove, and what they do not

Every path executes under the Clarity 5 `as-contract?` allowances; the
allowances are load-bearing (a twin declared one unit short aborts while the
correct contract succeeds); bad inputs are rejected with the intended errors
(ERR-INVALID-RATIO u1002, ERR-SLIPPAGE u1000); and the router never holds a
residue, so a leg cannot silently under-pay or strand funds. There are no admin
or rescue functions, no state, and each call is atomic.

Not covered: adversarial pool state (a venue returning less than its own quote
is bounded by `min-out`, which the front end sets from the quote and slippage),
and price impact at sizes far beyond what was simulated.

## Front-end post-conditions (deny mode)

`verify-smart-postconditions.mjs` builds the exact transactions the front ends
submit (same post-condition list, `postConditionMode: Deny`) as raw unsigned
txs and runs them on a fork: 4/4 clean
(https://stxer.xyz/simulations/mainnet/2e3cc740de0d544bf0531711d00a1176).
Lesson it caught: the router re-decides the bridge at execution time, so a list
built from the front end's earlier `compare-*` read was stale by one block and
aborted ("STX moved by univ2-pool-0070 but not checked"). Both bridge families
are now always whitelisted (all `willSendGte(0)`); the amounts the user and the
router are held to are unchanged.
