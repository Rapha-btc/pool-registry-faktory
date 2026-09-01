# ROCK relaunch: gated pool-3 + 1B single-sided

Pool-2 was too shallow (~$100) to price a single-sided offering safely, and its
gate is broken by design: `is-approved-caller` has the
`(is-eq tx-sender contract-caller)` escape hatch (line 273) so direct wallet
calls swap right through, and `initialize-pool` auto-approved fakfun-core-v2
(line 244). Fix = the proven MIA pattern: a fresh gated pool that freezes the
pairing price while sBTC deposits accumulate, one go button.

## Contracts (mainnet, block 8,895,371, deployer SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22)

| contract | what | source |
|---|---|---|
| `rock-faktory-pool-3` | ROCK/sBTC AMM, fork of mia-pool-faktory: swaps gated incl. direct calls (no escape hatch), no auto-approve at init; add/remove liquidity open | `contracts/rock-faktory-pool-3.clar` |
| `rock-single-faktory` | pepe-style single-sided vs pool-3: dynamic depositor (Highroller seeds 1B ROCK = 1e15), ENTRY u3024 (~3w) then depositor sweeps unused via `withdraw-remaining-token`, LOCK u12960 (~90d) then full-LP exit split 60/40 user/depositor both sides, `withdraw-lp-tokens-depositor` push-out | `contracts/rock-single-faktory.clar` |
| `rock-smart-faktory-2` | rock-smart-faktory repointed at `.rock-faktory-pool-3` | `contracts/rock-smart-faktory-2.clar` |
| `rock-arb-faktory-2` | rock-arb-faktory repointed at `.rock-faktory-pool-3` | `contracts/rock-arb-faktory-2.clar` |

`d-*.clar` are the comment-stripped, clarinet-formatted deploy variants - what
actually shipped via faktory-dao `/api/bot/deploy-contract` (Clarity 5,
account 0). Deploy txids: pool-3 `5801e286...`, single `3e29b234...`,
smart-2 `aab1e640...`, arb-2 `500e3a2f...`.

## stxer mainnet-fork sims (all against real mainnet state)

Real actors: a 3.2B-ROCK whale plays Highroller, real sBTC holders deposit.
Seed ratio 6,317 uROCK/sat taken from pool-2's live reserves.

1. **`simul-rock-relaunch.js` - commented sources, 45/45**
   https://stxer.xyz/simulations/mainnet/48ac3946f0906bbc347a8607b93dba94
   Full arc: gated init, 1B seed, exact-ratio deposits, every guard
   (u403 gated swap + self-deposit + stranger ops, u404/u405 init, u406 dust,
   u407 early withdraw/sweep, u408 no/double deposit, u409 late entry),
   exact sweep of unused ROCK (`ok u305130000000000`), 60/40 exits verified
   to floor dust, single ends holding zero LP/sBTC/ROCK.

2. **Same harness with `DEPLOY_VARIANT=1` - d-sources, 45/45**
   https://stxer.xyz/simulations/mainnet/14e4d6e384b04fde3d39089604073ef1
   Proves the comment-stripped deploy variants behave identically.

3. **`simul-rock-relaunch-deployed.js` - LIVE contracts, 47/47**
   https://stxer.xyz/simulations/mainnet/2fd4e124394030a92b7cda53af82c097
   Same arc on the deployed principals (no deploys in the sim), plus the live
   routers after the gate opens: smart-2 buy/sell pure fak leg + Velar leg all
   ok, arb-2 `check-fak-bit-vel` + `arb-fak-bit-vel` execute ok.

Sim gotchas (bit us, will bite again): stxer 0.8.0 caps deploys at Clarity5
(sources are C5-compatible - `as-contract?`/`current-contract`); Clarity `let`
bindings run before `asserts!`, so guard tests need funded senders or generic
err expectations.

## Launch runbook

1. Faktory ops wallet (`SMH8FRN30ERW1SX26NJTJCKTDR3H27NRJ6W75WQE`, holds all
   58,191 pool-2 LP) calls `remove-liquidity u58191` on pool-2
   (~67,713 sats + ~428M ROCK back).
2. Deployer `initialize-pool (lowest, highest)` on pool-3 at the honest ratio.
   Swaps stay gated; liquidity ops open.
3. Highroller calls `initialize-pool u1000000000000000` on
   `rock-single-faktory` (his wallet becomes the depositor).
4. Users `deposit-sbtc-for-lp` for up to ~3 weeks; every deposit pairs at the
   frozen ratio - the gate makes manipulation impossible.
5. Go button: `set-gated false` on pool-3 when the vault empties or the window
   ends (MIA precedent tx `0xe827c4fc...`). Depositor sweeps leftovers after
   u3024.
6. Rewire BEs/FEs from pool-2 to pool-3; ping chavita for core-v2
   `register-pool` if core routing is wanted.
