# flatearth-smart-faktory (DRAFT, not deployed)

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

- Not simulated. Next: `verify-flat-smart.js` on the `simul-flatearth-arb-v2.js`
  pattern (stxer 0.8.0, fund the sender with FLAT from `SP3W69…` via
  `ft-transfer?` - FLAT is at max supply, cannot mint).
- Not deployed. Same rollout as PEPE afterwards.
