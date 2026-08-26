# fakfun-smart-faktory

**Status: READY TO DEPLOY (not yet on-chain)** as `SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-smart-faktory`,
via faktory-dao `/api/bot/deploy-contract` (allowlisted in faktory-dao `93ea4504`).
On-chain bytes will be `contracts/d-fakfun-smart-faktory.clar`.

Split-router for FAKFUN (8 dec, `SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-faktory`,
asset name `FAKFUN`), derived from the deployed `flatearth-smart-faktory`. Same public
interface as `b-smart` / `mia-smart` / `pepe-smart` / `flatearth-smart`, so the FE/BE
integration is a config entry (see README-pepe-smart.md).

## Venues

| Leg | Venue |
|---|---|
| sBTC <-> FAKFUN (fak) | `fakfun-core-v2.execute` on the Charisma pool `SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS.sbtc-fakfun-amm-lp-v1` (registered in core-v2, pool-id lp-fee 100). The Charisma pool transfers its net `dy` exactly, so there is NO post-execute fee haircut (unlike the FLAT/PEPE faktory pools). |
| sBTC <-> STX bridge | `flag = true` BitFlow `xyk-pool-sbtc-stx-v-1-1`; `flag = false` Velar `univ2-pool-v1_0_0-0070` |
| STX <-> FAKFUN ("alex" leg) | BitFlow `xyk-pool-fakfun-stx-v-1-1` via `xyk-core-v-1-2` (x = FAKFUN, y = STX), replacing the template's Velar token pool |

So `flag` only chooses the bridge; the FAKFUN/STX hop is always the BitFlow xyk pool.
The `(flag bool)` parameter on the STX<->FAKFUN legs exists for interface parity.

It IS in Clarinet.toml (Clarity 5, epoch latest): every dependency resolves, so
`clarinet check` and `clarinet format` work directly on this one.

## Stxer sims (mainnet fork)

Harness: `node verify-fakfun-smart.js` (self-asserting; non-zero exit on any regression).
Impersonated holders: sBTC `SP2C7BCAP2NH3EYWCCVHJ6K0DMZBXDFKQ56KR7QN2`, STX
`SP9BP4PN74CNR5XT7CMAMBPA0GWC9HMB69HVVV51`, FAKFUN `SP3Q7W8W5FGFJGGWEKVW4PQ8MYTR3EMYQRJFN2RRC` (~34.8M).
Sizes: 100k sats / 100 STX / 100k FAKFUN.

- 2026-08-26, block 8847327, commented source: **53/53 green**
  https://stxer.xyz/simulations/mainnet/ae88a0bad4377b86d49ae45b224fc051
- 2026-08-26, deploy variant `SRC=./contracts/d-fakfun-smart-faktory.clar`: **53/53 green**
  https://stxer.xyz/simulations/mainnet/d1e1903d5f02852990d3f9246febe2ca

Coverage per run: deploy as Clarity 5; 21 read-onlys (liquidity getters, optimal
ratios, estimates, route compares, Charisma + xyk simulators); 24 core legs
(`buy-with-sbtc` / `buy-with-stx` / `sell-for-sbtc` / `sell-for-stx` x flag
bitflow/velar x ratio 0/50/100); 4 `smart-*` wrappers; zero residue (u0 STX /
sBTC / FAKFUN left in the router after all 28 writes).

The `d-` file is embedded byte-for-byte in faktory-dao
`server/utils/fakfun-smart-faktory-template.ts` and allowlisted as
`fakfun-smart-faktory` in `/api/bot/deploy-contract` (Clarity 5, account 0, fee 0.1 STX).

## Venue state observed on the fork (2026-08-26)

- Charisma pool: ~0.119 sBTC / ~391M FAKFUN. BitFlow FAKFUN/STX pool: ~135 STX (thin).
- The liquidity-proportional optimizer therefore lands at fak-ratio 99 for sBTC
  legs and alex-ratio 0 for STX legs, i.e. nearly everything routes through
  Charisma. The two venues are priced far apart, so the manual ratio extremes
  can beat the `smart-*` pick until they converge (e.g. `smart-sell-for-sbtc`
  100k FAKFUN -> 3,372 sats vs the ratio=0 bitflow leg on the same fork). This is
  the same heuristic as the b/mia/pepe/flat routers, not a bug in this contract.

## What the sims prove, and what they do not

Every path executes under the Clarity 5 `as-contract?` allowances, and the
router never holds a residue, so a leg cannot silently under-pay or strand
funds. There are no admin or rescue functions, no state, and each call is atomic.

Not yet run for this router: the negatives harness (ratio 101, min-out 1e30,
allowance twin) and the FE deny-mode post-condition check
(`verify-smart-postconditions.mjs`). Clone from the FLAT versions before wiring
the FE. Remember deny-mode PCs must whitelist BOTH bridge families (see
README-flatearth-smart.md).

## Deploy

```
curl -X POST https://faktory-dao.vercel.app/api/bot/deploy-contract \
  -H "Authorization: Bearer $CRON_SECRET" -H "Content-Type: application/json" \
  -d '{"contractName":"fakfun-smart-faktory"}'
```

After it confirms: add `SPV9K21….fakfun-smart-faktory` to `SMART_ROUTERS` in
faktory-dao `server/utils/smart-routers.ts` (stateId `fakfun-smart-faktory-swaps`)
and to the FE smart-routing config (`assetName: "FAKFUN"`).
