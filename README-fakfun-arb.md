# fakfun-arbitrage-faktory

**Status: READY TO DEPLOY (not yet on-chain)** as `SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-arbitrage-faktory`,
via faktory-dao `/api/bot/deploy-contract` (allowlisted, Clarity 5, account 0, fee 0.1 STX).
On-chain bytes will be `contracts/d-fakfun-arbitrage-faktory.clar`.

Atomic triangular arb for FAKFUN (8 dec, `SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-faktory`,
asset `FAKFUN`), modeled on `flatearth-arbitrage-faktory-v3`. Profit-or-revert: every path
asserts `token-out > token-in` (`ERR-NO-PROFIT u1001`) and `>= min-token-out`
(`ERR-SLIPPAGE u1000`); profit is paid to `DEPLOYER` (= tx-sender at deploy).

## Venues (FAKFUN has exactly two)

| Leg | Venue |
|---|---|
| sBTC <-> FAKFUN | Charisma pool `SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS.sbtc-fakfun-amm-lp-v1` via `fakfun-core-v2.execute` (registered in core-v2; transfers net `dy`, NO 0.1% haircut) |
| STX <-> FAKFUN | BitFlow `xyk-pool-fakfun-stx-v-1-1` via `xyk-core-v-1-2` (x = FAKFUN, y = STX) |
| sBTC <-> STX bridge | BitFlow `xyk-pool-sbtc-stx-v-1-1` (`bit`) or Velar `univ2-pool-v1_0_0-0070` (`vel`) |

Paths: `arb-fak-bit-bit`, `arb-fak-vel-bit`, `arb-bit-bit-fak`, `arb-bit-vel-fak`, each with a
`check-*` read-only twin returning `{profit, profitable, ...}`. Deployer-only
`rescue-sbtc` / `rescue-token` / `rescue-stx`.

## Clarity 5 gotcha

Clarity 5 has NO plain `as-contract` (deploy fails with
`use of unresolved function 'as-contract'`). Every leg runs under `as-contract?` with an
allowance for exactly the asset leaving the contract in that leg (`with-ft SBTC`,
`with-ft TOKEN`, `with-stx`), including the payout to `DEPLOYER` and the rescue functions.
The deployed FLAT arb v3 (Clarity 3) cannot be copied verbatim into a Clarity 5 deploy.

Read-only functions use literal principals; public/private paths use constants
(`TOKEN`, `SBTC`, `TOKEN-ASSET`, `SBTC-ASSET`), matching the deployed smart routers.

## Stxer sims (mainnet fork)

Harness: `node simul-fakfun-arb.js` (self-asserting; `SRC=./contracts/d-fakfun-arbitrage-faktory.clar`
runs the deploy variant). Impersonated executor: FAKFUN whale
`SP3Q7W8W5FGFJGGWEKVW4PQ8MYTR3EMYQRJFN2RRC` (~34.8M). Sizes 5k / 20k / 50k FAKFUN.

- 2026-08-26, block 8847367, commented source: **PASS**
  https://stxer.xyz/simulations/mainnet/5c0f5a6019bbaeec1e619db39242a952
- 2026-08-26, deploy variant `d-`: **PASS**
  https://stxer.xyz/simulations/mainnet/de4d06348c0394acdda14dd736c7feb5

Coverage per run: deploy as Clarity 5; 12 `check-*` evaluations (4 routes x 3 sizes, all
sane - no garbage math); 12 executions with `min-out u1`, every one refusing with
`ERR-NO-PROFIT u1001`. On the fork the two venues sit within ~2-5% round trip, so no arb
exists at these sizes; the refusals are the correct behavior, and the execution path
(allowances, both bridges, both directions) is exercised end to end.

## Venue state observed on the fork (2026-08-26)

Charisma pool ~0.119 sBTC / ~391M FAKFUN; BitFlow FAKFUN/STX ~135 STX (thin). An arb bot
(`SP2H674...psis` / `nana`) already works this pair via Charisma <-> BitFlow, which is why
the spread stays inside costs.
