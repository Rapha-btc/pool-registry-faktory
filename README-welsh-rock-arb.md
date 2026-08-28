# welsh-arb-faktory / rock-arb-faktory

**Status: READY TO DEPLOY 2026-08-28.** Deploy variants `contracts/d-welsh-arb-faktory.clar`
(29/29 https://stxer.xyz/simulations/mainnet/5bdb778ce90415839baa04cfabc90777) and
`contracts/d-rock-arb-faktory.clar` (17/17 https://stxer.xyz/simulations/mainnet/cf40ebda2502d5094d1b26572a6339fc),
embedded byte-for-byte in faktory-dao `backend/server/utils/{welsh,rock}-arb-faktory-template.ts`
and allowlisted in `/api/bot/deploy-contract` (Clarity 5, account 0, fee 0.1 STX):

```
curl -X POST https://faktory-dao-backend.vercel.app/api/bot/deploy-contract \
  -H "Authorization: Bearer $CRON_SECRET" -H "Content-Type: application/json" \
  -d '{"contractName":"welsh-arb-faktory"}'

curl -X POST https://faktory-dao-backend.vercel.app/api/bot/deploy-contract \
  -H "Authorization: Bearer $CRON_SECRET" -H "Content-Type: application/json" \
  -d '{"contractName":"rock-arb-faktory"}'
```

Profits go to DEPLOYER (account 0), so that account must hold WELSH / ROCK to run a route.
Files:
`contracts/welsh-arb-faktory.clar`, `contracts/rock-arb-faktory.clar`, harness `verify-arb.js`,
Clarinet.toml entries. **Clarity 5** (2026-08-28 rework at Rapha's request): every leg runs under
`as-contract?` with an explicit `with-ft` / `with-stx` allowance (pepe-smart pattern), the ALEX
legs add the `alex` / `wstx` / `wcorgi` pass-through allowances, payouts and rescues use
`current-contract` - the `(define-constant CONTRACT (as-contract tx-sender))` of the LEO arb is gone.

Both are profit-or-revert triangular arbs TOKEN -> sBTC -> STX -> TOKEN (and reverse), profits paid
to DEPLOYER, `rescue-*` for the deployer. Executor must hold the token (same as flatearth-arb).

## welsh-arb-faktory (8 routes, byte-derived from leo-arbitrage-faktory-v2)

| Leg | Venue |
|---|---|
| fak | `fakfun-core-v2.execute` on `welshcorgicoin-faktory-pool-v2` (0.1% sell haircut) |
| bit | BitFlow `xyk-pool-welsh-stx-v-1-1` (x = WELSH, y = STX) + `xyk-pool-sbtc-stx-v-1-1` bridge |
| vel | Velar old-core **pool 27** wstx/welsh via `univ2-router` (dust, ~2.7k STX) + `univ2-pool-0070` bridge |
| alex | ALEX 2-hop STX <-> ALEX <-> WELSH (`token-wcorgi`, 8-dec) |

Routes: `arb-fak-bit-bit`, `arb-fak-vel-vel`, `arb-bit-bit-fak`, `arb-vel-vel-fak`,
`arb-fak-bit-alex`, `arb-fak-vel-alex`, `arb-alex-bit-fak`, `arb-alex-vel-fak`, each with a
`check-*` read-only quote.

Sim (`node verify-arb.js welsh`, 2026-08-28): **29/29 green**
https://stxer.xyz/simulations/mainnet/418a3b4eed809cd3241a0a2ee701f14b - deploy, core-v2
approve-caller, 16 check-* quotes (100k and 1M WELSH), all 8 routes revert `(err u1001)`
ERR-NO-PROFIT at 100k WELSH (no edge on the fork), zero residue.

Re-run 2026-08-28 (fresh fork): **29/29** https://stxer.xyz/simulations/mainnet/7d6d940b7cdf20bbb868382da0e13dbf

Clarity 5 rework, 2026-08-28: **29/29** https://stxer.xyz/simulations/mainnet/66db2f321d53d7e69cc9a94f9e4cf4b1

### Imbalance proof (`node verify-welsh-arb-imbalance.js`): **30/30**
https://stxer.xyz/simulations/mainnet/b6a6c6ad1cdf010435f78cb4dae50926 (block 8861562)

1. All 8 quotes at 100k WELSH: no edge (fak-first routes ~87k out, reverse ~95k out).
2. sBTC whale buys WELSH on `welshcorgicoin-faktory-pool-v2` with 100k sats via core-v2
   (pool ~236k sats deep -> gets 379.5M WELSH, i.e. the fak price roughly doubles).
3. Quotes after: every fak-first route profitable, `check-fak-bit-bit` 100k -> 172.1k WELSH
   (+72%); reverse routes ~48k out.
4. Execution, 100k WELSH each: `arb-fak-bit-bit` **(ok 100k -> 172.1k)**, `arb-fak-vel-vel`
   (ok -> 137.1k), `arb-fak-bit-alex` (ok -> 115.4k), then `arb-fak-vel-alex` reverts
   `(err u1001)` because the first three already closed the gap. All 4 reverse routes revert
   u1001. Zero residue. So the contract fires when an edge exists and refuses atomically once
   it is gone.

   Clarity 5 rework re-run: **30/30** https://stxer.xyz/simulations/mainnet/a1012859df4c3070d07cf6f57e55b372
   (arb-fak-bit-bit 100k -> 172.2k, then 137.1k, 115.2k, then u1001).

## rock-arb-faktory (4 routes)

| Leg | Venue |
|---|---|
| fak | `rock-faktory-pool-2.execute` called **directly** (pool not registered in core-v2; its gate passes under `as-contract`); 0.1% sell haircut |
| vel (token) | Velar old-core **pool 18** wstx/rock via `univ2-router` - the only ROCK/STX venue |
| bridge | bit = BitFlow xyk sbtc-stx, vel = Velar univ2-pool-0070 |

Routes: `arb-fak-bit-vel`, `arb-fak-vel-vel`, `arb-vel-bit-fak`, `arb-vel-vel-fak` + `check-*`.

Sim (`node verify-arb.js rock`, 2026-08-28): **17/17 green**
https://stxer.xyz/simulations/mainnet/e4957c01628fa70efba5b4654f89f4f1 (re-run
https://stxer.xyz/simulations/mainnet/9875999cd27a8d7027265117c9c429f8, same result). At 10M ROCK the two
fak-first routes were PROFITABLE on the fork: `arb-fak-bit-vel` 10.00M -> 10.68M ROCK (+6.8%),
`arb-fak-vel-vel` 10.00M -> 10.12M. ROCK trades ~11% richer on the fak pool (0.000178 sat) than on
Velar 18 (0.00016 sat); both pools are thin so the edge closes fast. Reverse routes revert u1001.

Clarity 5 rework, 2026-08-28: **17/17** https://stxer.xyz/simulations/mainnet/396c2383514b9ffc8bced840c394d723
(`arb-fak-bit-vel` 10.00M -> 10.68M ROCK still profitable).

## Next

Keeper wiring as flatearth-arb (faktory-be keeper, executor holds the
token); `d-` variants + faktory-dao templates if they go to mainnet.
