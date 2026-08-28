# welsh-arb-faktory / rock-arb-faktory

**Status: DRAFTS 2026-08-28, not deployed, NOT committed** (per Rapha). Files:
`contracts/welsh-arb-faktory.clar`, `contracts/rock-arb-faktory.clar`, harness `verify-arb.js`,
Clarinet.toml entries (Clarity 3, like `leo-arbitrage-faktory-v2` they derive from - `as-contract`
inside `define-constant` is illegal from Clarity 4 on).

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

## rock-arb-faktory (4 routes)

| Leg | Venue |
|---|---|
| fak | `rock-faktory-pool-2.execute` called **directly** (pool not registered in core-v2; its gate passes under `as-contract`); 0.1% sell haircut |
| vel (token) | Velar old-core **pool 18** wstx/rock via `univ2-router` - the only ROCK/STX venue |
| bridge | bit = BitFlow xyk sbtc-stx, vel = Velar univ2-pool-0070 |

Routes: `arb-fak-bit-vel`, `arb-fak-vel-vel`, `arb-vel-bit-fak`, `arb-vel-vel-fak` + `check-*`.

Sim (`node verify-arb.js rock`, 2026-08-28): **17/17 green**
https://stxer.xyz/simulations/mainnet/e4957c01628fa70efba5b4654f89f4f1. At 10M ROCK the two
fak-first routes were PROFITABLE on the fork: `arb-fak-bit-vel` 10.00M -> 10.68M ROCK (+6.8%),
`arb-fak-vel-vel` 10.00M -> 10.12M. ROCK trades ~11% richer on the fak pool (0.000178 sat) than on
Velar 18 (0.00016 sat); both pools are thin so the edge closes fast. Reverse routes revert u1001.

## Next (after review)

Commit when Rapha says so; keeper wiring as flatearth-arb (faktory-be keeper, executor holds the
token); `d-` variants + faktory-dao templates if they go to mainnet.
