# rock-smart-faktory

**Status: READY TO DEPLOY 2026-08-28** - `contracts/rock-smart-faktory.clar`, deploy variant
`contracts/d-rock-smart-faktory.clar` (55/55 https://stxer.xyz/simulations/mainnet/254e8598138e7a0cdaf7199f0ec03a01),
template `faktory-dao backend/server/utils/rock-smart-faktory-template.ts`, allowlisted as
`rock-smart-faktory` in `/api/bot/deploy-contract`:

```
curl -X POST https://faktory-dao.vercel.app/api/bot/deploy-contract \
  -H "Authorization: Bearer $CRON_SECRET" -H "Content-Type: application/json" \
  -d '{"contractName":"rock-smart-faktory"}'
```

Split-router for ROCK (6 dec, `SP4M2C88EE8RQZPYTC4PZ88CE16YGP825EYF6KBQ.stacks-rock`, asset `rock`),
derived from `pepe-smart-faktory`. Same public interface as the family.

## Venues

| Leg | Venue |
|---|---|
| sBTC <-> ROCK (fak) | `rock-faktory-pool-2.execute` called **directly** (see below). Gated pool, 0.3% LP rebate, sell pays `dy - 0.1%` so the router shaves 0.1% off dy. The old `rock-faktory-pool` (v1) is EMPTY (0 sBTC / 0 ROCK) and NOT used. |
| sBTC <-> STX bridge | `flag = true` BitFlow `xyk-pool-sbtc-stx-v-1-1`; `flag = false` Velar `univ2-pool-v1_0_0-0070` |
| STX <-> ROCK ("alex" leg) | Velar old-core **pool id 18** wstx/rock via `univ2-router swap-exact-tokens-for-tokens` (reserve0 = wstx, reserve1 = rock, fee 997/1000). LP token `SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx-rock`. Only ROCK/STX venue; `flag` therefore only picks the bridge (as flatearth-smart). |

Not a ROCK venue: Velar `univ2-pool-v1_0_0-0066` is wSTX-**Rocket** (`SP3AFTJ38….rocket-stxcity`),
a different token.

## Why the fak leg bypasses fakfun-core-v2

`rock-faktory-pool-2` is not in core-v2's `pool-contracts` map (`get-pool-by-contract` -> none),
so `fakfun-core-v2.execute` fails with `ERR_POOL_NOT_FOUND u1003` (first sim: 35/55). The pool is
gated, but its `is-approved-caller` is `(or (is-eq tx-sender contract-caller) approved-map)`, and
inside `as-contract?` the router is both tx-sender and contract-caller, so a direct
`POOL execute` passes. Cost: no core-v2 print for the fak leg; the router's own outer print is
what `poll-smart-swaps` reads anyway.

## Venue facts verified on-chain (2026-08-28)

- `rock-faktory-pool-2 get-reserves-quote`: dx 71,783 sats / dy 403M ROCK. Deployed block 6853051.
- Velar `univ2-core get-pool-id wstx stacks-rock` = 18; reserves 1,802 STX / 3.68B ROCK.
- Legacy DB (faktory-dao `tokens`): ROCK row is `status completed / phase in-curve`,
  `pool_contract = dex_contract = rock-faktory-pool-2`, `amm_contract = rock-faktory-pool`.
  `/markets/…rock-faktory-pool` (v1) shows the pre-launch scaffold only because the resolver
  matches token/dex/pool contracts, not `amm_contract`; `/markets/…rock-faktory-pool-2` is the
  live market. No DB change needed.

## Stxer sim (mainnet fork)

Harness: `node verify-rock-smart.js`. Holders: sBTC `SP2C7BCAP2NH3EYWCCVHJ6K0DMZBXDFKQ56KR7QN2`,
STX `SP9BP4PN74CNR5XT7CMAMBPA0GWC9HMB69HVVV51`, ROCK `SP1J9JVDWMAM63RZM54R43TK84XCT85C2W254TMYX`
(~3.2B). Sizes 100k sats / 100 STX / 100M ROCK.

- 2026-08-28: **55/55 green** https://stxer.xyz/simulations/mainnet/a70c71108c05c137de0c1cfd9e6cd1a6
  (deploy, 23 read-onlys, 24 core legs, 4 smart wrappers, zero residue).

Observed: fak pool ~219 STX-equiv vs Velar 1,802 STX -> fak-ratio 5 / alex-ratio 94. Both venues
are thin; 100k sats moves them a lot. `min-out` from the FE estimate is the protection.

## Next (after review)

Negatives harness, `d-` deploy variant, faktory-dao template + allowlist, SMART_ROUTERS /
SMART_TOKENS (key ROCK, `assetName: "rock"`), both bridges whitelisted in deny-mode PCs.
