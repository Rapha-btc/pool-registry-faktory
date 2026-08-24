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
- Not simulated yet. Next: a `verify-pepe-smart.js` on the mia pattern
  (`verify-mia-smart.js`): fork mainnet, deploy, fund a sender with PEPE via
  `ft-transfer?`, run buy/sell at ratio 0 / 50 / 100 for both flags, assert
  `estimate-*` == executed output and that every allowance holds.
- Not deployed. Deploy via faktory-dao `/api/bot/deploy-contract` once the sim
  is green, then add to `SMART_ROUTERS` (backend) and `SMART_TOKENS` (fak.fun +
  legacy) with `assetName: "tokensoft-token"`.
