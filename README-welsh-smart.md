# welsh-smart-faktory

**Status: READY TO DEPLOY 2026-08-28** - `contracts/welsh-smart-faktory.clar`, deploy variant
`contracts/d-welsh-smart-faktory.clar`, template embedded in faktory-dao and allowlisted.

Split-router for WELSH (6 dec, `SP3NE50GEXFG9SZGTT51P40X2CKYSZ5CC4ZTZ7A2G.welshcorgicoin-token`,
asset `welshcorgicoin`), modeled on the deployed `pepe-smart-faktory`. Same public interface as
`b-smart` / `mia-smart` / `pepe-smart` / `leo-smart` / `lwb-smart` (function names, argument
types, tuple keys, print shape), so FE/BE integration is a config entry.

## Venues

| Leg | Venue |
|---|---|
| sBTC <-> WELSH (fak) | `fakfun-core-v2.execute` on `welshcorgicoin-faktory-pool-v2` (gated pool, core-v2 approved, registered in core; 0.3% LP rebate inside the quote; sell pays `dy - 0.1%` faktory fee so the router shaves 0.1% off dy like pepe-smart). The retired `welshcorgicoin-faktory-pool` (v1, ~328 sats) is NOT used. |
| sBTC <-> STX bridge | `flag = true` BitFlow `xyk-pool-sbtc-stx-v-1-1`; `flag = false` Velar `univ2-pool-v1_0_0-0070` |
| STX <-> WELSH ("alex" leg) | `flag = true` BitFlow `xyk-pool-welsh-stx-v-1-1` (**x = WELSH, y = STX**, reversed vs `xyk-pool-stx-lwb`: buy = `swap-y-for-x`); `flag = false` ALEX 2-hop STX <-> ALEX <-> WELSH via `amm-pool-v2-01 swap-helper-a` (`token-wstx-v2` / `token-alex` / `token-wcorgi`, factors 1e8, 8-dec `*100` in / `/100` out, pass-through allowances `alex` / `wstx` / `wcorgi` as leo-smart) |

So `flag` picks a whole family, as in pepe-smart: true = BitFlow bridge + BitFlow welsh-stx,
false = Velar bridge + ALEX 2-hop. The `compare-*` read-onlys evaluate both and the `smart-*`
wrappers take the better one.

Not wired (dust): Velar STX-WELSH old-core pool (~2.7k STX, LP `wstx-welsh`), Velar WELSH-aeUSDC.

Ratio proxy for the "alex" leg: BitFlow = pool y-balance (STX); ALEX = the alex/wcorgi hop's
ALEX balance converted to STX at the STX/ALEX spot (~25k STX; the shared STX/ALEX hop is ~530k
STX so the wcorgi hop bounds the route). Safety is the signed `min-out`, never the ratio.

## Venue facts verified on-chain (2026-08-28)

- `welshcorgicoin-faktory-pool-v2 get-reserves-quote`: dx 236,134 sats / dy 1.28M WELSH.
  `get-swap-quote` on a 100k WELSH sell shows the 0.1% `fee`; a 1000 WELSH quote rounds it to 0,
  which is why the first draft dropped the haircut and failed 8 sells with `(err u1)`.
- `xyk-pool-welsh-stx-v-1-1 get-pool`: x-token welshcorgicoin-token, y-token token-stx-v-1-2,
  88.6M WELSH / 52,039 STX, fees 10+20 bps each side.
- ALEX `get-pool-details token-alex token-wcorgi u100000000`: 2.20M ALEX / 42.9M WCORGI, 0.5%
  per hop. `get-helper-a wstx-v2 -> alex -> wcorgi` for 400 STX = 669,868 WELSH.
- Asset names: `welshcorgicoin` (WELSH), `wcorgi` (ALEX wrapper).

## Stxer sims (mainnet fork)

Harness: `node verify-welsh-smart.js` (self-asserting; `SRC=./contracts/d-welsh-smart-faktory.clar`
runs the deploy variant). Impersonated holders: sBTC `SP2C7BCAP2NH3EYWCCVHJ6K0DMZBXDFKQ56KR7QN2`,
STX `SP9BP4PN74CNR5XT7CMAMBPA0GWC9HMB69HVVV51`, WELSH `SP3AP6DRSQ6P4FETB5M33D082Q2ABGJW60MT6103Q`
(~745M). Sizes 100k sats / 100 STX / 100k WELSH.

- 2026-08-28, final source (fak + BitFlow/ALEX): **55/55 green**
  https://stxer.xyz/simulations/mainnet/da4dd815cec05759f865ca9ee7cbf763
- 2026-08-28, deploy variant `d-welsh-smart-faktory.clar`, block 8861373: see the
  `verify-welsh-smart.js` run recorded in the commit message / template header.

Earlier drafts without the fak leg (both legs STX venues) ran 53/53 three times
(c383eb70…, 9d2c4628…, ebfb244c…); superseded once the v2 fak pool was wired.

Coverage per run: deploy as Clarity 5; 23 read-onlys; 24 core legs (4 fns x flag x ratio
0/50/100); 4 `smart-*` wrappers; zero residue (u0 STX / sBTC / WELSH left in the router).

Observed on the fork: fak pool ~720 STX-equiv vs BitFlow 52k / ALEX 25k, so the optimizer
lands at fak-ratio 1-3 / alex-ratio 96-98: nearly everything routes through the STX venues.
`smart-buy` picked BitFlow, `smart-sell` picked Velar+ALEX at these sizes.

`clarinet check` (2026-08-28): compiles; warnings are the `unwrap-panic` quotes and
unchecked-data hints, same as the other routers. The three errors clarinet prints are
pre-existing (mia-smart DLMM router, lwb-smart / fakfun-smart fak pools unresolved).

## Deploy

The `d-` file is embedded byte-for-byte in faktory-dao
`backend/server/utils/welsh-smart-faktory-template.ts` and allowlisted as `welsh-smart-faktory`
in `/api/bot/deploy-contract` (Clarity 5, account 0, fee 0.1 STX):

```
curl -X POST https://faktory-dao.vercel.app/api/bot/deploy-contract \
  -H "Authorization: Bearer $CRON_SECRET" -H "Content-Type: application/json" \
  -d '{"contractName":"welsh-smart-faktory"}'
```

After deploy: `SMART_ROUTERS` (faktory-be + faktory-dao, keep in step) and `SMART_TOKENS`
(fak.fun + legacy, key WELSH, `assetName: "welshcorgicoin"`). Deny-mode post-conditions must
whitelist BOTH bridges (`willSendGte(0)`) because the router re-decides the bridge at
execution time (lesson from pepe-smart).
