# pepe-smart-faktory (DRAFT, not deployed)

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
  **50/50 checks green** (https://stxer.xyz/simulations/mainnet/e4204738c5a541d39796d7709530ae57).
  Deploy as Clarity 5, all 16 read-onlys, 24 core legs (4 fns x 2 flags x
  ratio 0/50/100), 4 smart-* wrappers. holder SP2022PJ05WB4VXP8HTVFAFE186AM94A4WYQ1RQY2 (710k PEPE), 100k PEPE per sell; smart-buy picked Velar at fak-ratio 62, smart-sell picked BitFlow at 69.
- Not deployed. Deploy via faktory-dao `/api/bot/deploy-contract` once the sim
  is green, then add to `SMART_ROUTERS` (backend) and `SMART_TOKENS` (fak.fun +
  legacy) with `assetName: "tokensoft-token"`.
