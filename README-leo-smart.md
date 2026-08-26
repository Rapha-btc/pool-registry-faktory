# leo-smart-faktory

**Status: READY TO DEPLOY (not yet on-chain)** as `SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.leo-smart-faktory`,
via faktory-dao `/api/bot/deploy-contract` (allowlisted, Clarity 5, account 0, fee 0.1 STX).
On-chain bytes will be `contracts/d-leo-smart-faktory.clar`.

Split-router for LEO (6 dec, `SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token`, asset `leo`),
derived from the deployed `flatearth-smart-faktory`. Same public interface as
`b-smart` / `mia-smart` / `pepe-smart` / `flatearth-smart` / `fakfun-smart`, so the FE/BE
integration is a config entry.

## Venues

| Leg | Venue |
|---|---|
| sBTC <-> LEO (fak) | `fakfun-core-v2.execute` on `leo-faktory-pool-v2` (FLAT pool family: 0.1% post-execute haircut on sells kept) |
| sBTC <-> STX bridge | `flag = true` BitFlow `xyk-pool-sbtc-stx-v-1-1`; `flag = false` Velar `univ2-pool-v1_0_0-0070` |
| STX <-> LEO ("alex" leg) | ALEX 2-hop STX <-> ALEX <-> LEO via `amm-pool-v2-01 swap-helper-a` (8-dec: `*100` in, `/100` out), lifted from the deployed `leo-arbitrage-faktory-v2`. Deepest LEO/STX venue (~$65k). |

Not routed here (the arb contract covers them): BitFlow xyk `xyk-pool-leo-stx-v-1-1`
(~3.5k STX), BitFlow DLMM `dlmm-pool-leo-stx-v-1-bps-50` (bin math, no simple quote),
Velar pool 28 via `univ2-router` (~5.3k STX; no per-pool contract instance).

Dex split ratio uses the STX depth of the ALEX STX/ALEX hop as the venue's liquidity proxy;
safety is always the signed `min-out`, never the ratio.

## ALEX allowance gotcha

ALEX's `swap-helper-a` routes the intermediate `alex` token AND the `wstx` / `wleo` wrapper
FTs THROUGH the caller inside one call. Under Clarity 5 `as-contract?` that means the ALEX
legs need pass-through allowances on top of `with-stx` / `with-ft TOKEN`:
`(with-ft token-alex "alex" ALEX-PASSTHROUGH) (with-ft token-wstx-v2 "wstx" ALEX-PASSTHROUGH)
(with-ft token-wleo "wleo" ALEX-PASSTHROUGH)` (u128 max). Without them every ALEX leg fails
`(err u128)` - the first sim run was 32/52 for exactly this reason. None of those assets rest
in the router between calls, so the cap only bounds what ALEX's own code can move within
that call.

## Stxer sims (mainnet fork)

Harness: `node verify-leo-smart.js` (self-asserting; `SRC=./contracts/d-leo-smart-faktory.clar`
runs the deploy variant). Impersonated holders: sBTC `SP2C7BCAP2NH3EYWCCVHJ6K0DMZBXDFKQ56KR7QN2`,
STX `SP9BP4PN74CNR5XT7CMAMBPA0GWC9HMB69HVVV51`, LEO `SP17A1AM4TNYFPAZ75Z84X3D6R2F6DTJBDJ6B0YF`
(~500M). Sizes 100k sats / 100 STX / 100k LEO.

- 2026-08-26, block 8847367, commented source: **52/52 green**
  https://stxer.xyz/simulations/mainnet/08bf8c98dc06869f5020e04b772afd37
- 2026-08-26, deploy variant `d-`: **52/52 green**
  https://stxer.xyz/simulations/mainnet/e232b55b7e0a337614f05da7f5c2a940

Coverage per run: deploy as Clarity 5; 20 read-onlys; 24 core legs (`buy-with-sbtc` /
`buy-with-stx` / `sell-for-sbtc` / `sell-for-stx` x flag bitflow/velar x ratio 0/50/100);
4 `smart-*` wrappers; zero residue (u0 STX / sBTC / LEO left in the router).

## Venue state observed on the fork (2026-08-26)

`leo-faktory-pool-v2` ~0.0217 sBTC side vs ALEX STX/ALEX hop ~532k STX depth, so the
optimizer lands at fak-ratio 1 / alex-ratio 98: nearly everything routes through ALEX. The
manual ratio extremes can beat the `smart-*` pick until the venues converge - same
heuristic as the other routers, not a bug in this contract.

After deploy: add to backend `SMART_ROUTERS` + FE smart config (assetName `leo`, 6 dec).
