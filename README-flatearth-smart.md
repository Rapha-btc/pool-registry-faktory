# flatearth-smart-faktory

**Status: DEPLOYED 2026-08-24** at `SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.flatearth-smart-faktory`
(txid `7749a6818dd50dedad2b746041d4f9bc1827cfb5d8426e2fedc457935ebc9873`), via faktory-dao `/api/bot/deploy-contract`. On-chain bytes = `contracts/d-flatearth-smart-faktory.clar`.

Split-router for FlatEarth (FLAT, 6 dec), modeled on the deployed
`mia-smart-faktory`. Same public interface as `b-smart` / `mia-smart`, so the
FE/BE integration is a config entry (see README-pepe-smart.md).

## Venues

| Leg | Venue |
|---|---|
| sBTC <-> FLAT (fak) | `fakfun-core-v2.execute` on `flatearth-faktory-pool-v2` (sell shaves the 0.1% faktory fee, as `flatearth-arbitrage-faktory-v3` does) |
| sBTC <-> STX bridge | `flag = true` BitFlow `xyk-pool-sbtc-stx-v-1-1`; `flag = false` Velar `univ2-pool-v1_0_0-0070` |
| STX <-> FLAT | Velar `univ2-pool-v1_0_0-0003` only. **reserve0 = STX, reserve1 = FLAT** (the orientation that broke flatearth-arb-v2's checks). BitFlow `xyk-pool-stx-flat-v-1-1` is dust (~22 STX) and is not wired. |

So `flag` only chooses the bridge; the FLAT hop is always Velar 0003. The
`(flag bool)` parameter on the FLAT legs exists for interface parity.

Asset name for the `with-ft` allowance: `FlatEarth`
(`SP3W69VDG9VTZNG7NTW1QNCC1W45SNY98W1JSZBJH.flat-earth-stxcity`).

## Why it is not in Clarinet.toml

`flat-earth-stxcity` and `flat-earth-stxcity-dex` call each other, so clarinet
cannot order the FLAT token and reports the fak pool as an unresolved contract.
The arb contracts have the same problem and are validated with stxer. To
type-check this router with clarinet, substitute the PEPE principals (same
interfaces) into a temp copy:

```
sed -e "s#'SP3W69VDG9VTZNG7NTW1QNCC1W45SNY98W1JSZBJH.flat-earth-stxcity#'SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz#g" \
    -e "s#flatearth-faktory-pool-v2#pepe-faktory-pool-v2-2#g" -e 's#"FlatEarth"#"tokensoft-token"#' \
    contracts/flatearth-smart-faktory.clar > contracts/zz-flat-typecheck.clar
# add [contracts.zz-flat-typecheck] (clarity_version 5) to Clarinet.toml, clarinet check, then remove both
```

Done 2026-08-24: compiles, warnings identical in kind to mia-smart.

## Status

- stxer mainnet fork, 2026-08-24, block 8833457: `node verify-flat-smart.js` ->
  **48/48 checks green** (https://stxer.xyz/simulations/mainnet/7ade75aacdb084809288d030c2b91173).
  Deploy as Clarity 5, read-onlys, 24 core legs (4 fns x 2 flags x ratio
  0/50/100), 4 smart-* wrappers. seller = deployer EOA SP3W69 (~31.5M FLAT), 20k FLAT per sell; fak pool holds only ~0.0106 sBTC so the split lands at fak-ratio 6-7 and Velar 0003 carries the rest.
- Deployed (see top). Same rollout as PEPE (`assetName: "FlatEarth"`).

- Negatives `node verify-flat-smart-negatives.js` -> **12/12** (ratio 101, min-out 1e30, allowance twin)
  (https://stxer.xyz/simulations/mainnet/c465adac5e45e1658e914a57d8579abc).
- Zero residue: u0 STX / sBTC / FLAT left in the router after every trade (happy harness 51/51:
  https://stxer.xyz/simulations/mainnet/4fbbf389a12fc74b7ea27703b58eb400).
- Deploy variant `contracts/d-flatearth-smart-faktory.clar` runs the same harness 51/51
  (https://stxer.xyz/simulations/mainnet/450a5947bd7b48ccaa24190f928183e6) and is embedded byte-for-byte
  in faktory-dao `server/utils/flatearth-smart-faktory-template.ts`, allowlisted as
  `flatearth-smart-faktory` in `/api/bot/deploy-contract` (Clarity 5, account 0, fee 0.1 STX).

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
