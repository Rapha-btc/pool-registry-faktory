# mia-arbitrage-faktory

Atomic cross-venue arbitrage for MIA (miamicoin-v2). MIA trades on two
independent markets:

- **Faktory** — `SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.mia-pool-faktory`,
  a constant-product sBTC/MIA pool routed through `fakfun-core-v2`.
- **ALEX** — `SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01`,
  the wSTX/wMIA pool (pool-id 16, factor `u100000000`, 0.5% both sides).

When the two disagree on price, this contract closes the gap in one
transaction and keeps the difference. It holds nothing between calls and
has no owner keys beyond a rescue sweep to the deployer.

## The loop

The two markets quote MIA in different base assets (sBTC on Faktory, STX on
ALEX), so a full circle needs a bridge to move value between sBTC and STX.
Each route is `fak -> bridge -> alex` (forward) or `alex -> bridge -> fak`
(reverse), starting and ending in MIA:

```
forward:  MIA --(fak sell)--> sBTC --(bridge)--> STX --(alex buy)--> MIA
reverse:  MIA --(alex sell)--> STX --(bridge)--> sBTC --(fak buy)--> MIA
```

If the MIA that comes out exceeds the MIA that went in, the trade is
profitable; otherwise it reverts (`ERR-NO-PROFIT u1001`). The profit is
swept to the deployer; nothing is left in the contract.

## Bridges

The sBTC<->STX middle leg can go through three venues; the keeper picks the
cheapest at call time:

| Bridge         | Contract                                             |
| -------------- | ---------------------------------------------------- |
| Bitflow XYK    | `SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2` |
| Velar          | `SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070` |
| Bitflow DLMM   | `SM1FKXGNZJWSTWDWXQZJNF7B5TV5ZB235JTCXYXKD.dlmm-swap-router-v-1-2` |

That gives six routes:

| Function            | Bridge      | Direction |
| ------------------- | ----------- | --------- |
| `arb-fak-bit-alex`  | Bitflow XYK | forward   |
| `arb-fak-vel-alex`  | Velar       | forward   |
| `arb-fak-dlmm-alex` | Bitflow DLMM| forward   |
| `arb-alex-bit-fak`  | Bitflow XYK | reverse   |
| `arb-alex-vel-fak`  | Velar       | reverse   |
| `arb-alex-dlmm-fak` | Bitflow DLMM| reverse   |

Each takes `(amt-in uint) (min-amt-out uint)`. The DLMM routes take a third
arg `(dlmm-pool uint)` — `u1`/`u2`/`u3` selecting a hardcoded
`dlmm-pool-stx-sbtc-v-N-bps-15`. There are three live DLMM pools mid-migration
(`v-1` legacy TVL, `v-2` the pool Bitflow's router traffic uses since
2026-08-14, `v-3` deployed but empty). The branches are hardcoded literals,
not a caller-supplied trait, so no input can point a route at a fake pool.

## Choosing the route

For the four XYK/Velar routes, a read-only `check-*` mirrors the exact
on-chain math and returns `{ amt-in, sbtc-out, stx-out, amt-out, profit,
profitable }`. The keeper polls all four and fires the most profitable.

DLMM has no read-only quote (the amount out depends on walking the pool's
bins, and the pool exposes only bin primitives — `get-bin-balances`,
`get-active-bin-id` — not a quote function). So the keeper prices the DLMM
routes off-chain (bin math from the pool primitives, or a full tx
pre-simulation) and relies on profit-or-revert on-chain. Each DLMM leg
asserts `in == amount` (`ERR-PARTIAL-FILL u1003`): if the swap would walk out
of the bins the router covers, it reverts instead of stranding funds
mid-route.

## Decimal and fee details

- **MIA is 6-dec; wMIA is 8-dec.** The ALEX legs multiply by `u100` going in
  and divide by `u100` coming out.
- **Faktory sell (`swap-b-to-a`) reports gross `dy`** but pays out
  `dy - 0.1%` (the faktory fee is charged on the sBTC output). The
  `swap-token-to-sbtc` leg shaves that 0.1% so the downstream bridge is
  handed the amount actually received.
- **`quote` vs `get-swap-quote`:** the pool's `quote` returns `{dx, dy, dk}`
  with no fee field; `get-swap-quote` (bare tuple) carries `fee`. The sell
  simulate uses `get-swap-quote` and returns `dy - fee`.

## Safety

- **No approval needed in `fakfun-core-v2`.** The core's gate keeps the
  `(is-eq tx-sender contract-caller)` escape hatch; when the arb calls the
  core inside `as-contract?`, both are the arb's own principal, so it passes.
- **Scoped allowances.** Every leg runs under `as-contract?` with an
  allowance (`with-ft` / `with-stx`) for exactly that leg's input, so no
  downstream venue can pull more than the leg intends to spend.
- **Profit-or-revert + slippage.** `min-amt-out` is the caller's slippage
  floor (`ERR-SLIPPAGE u1000`); `amt-out > amt-in` is the profit guard
  (`ERR-NO-PROFIT u1001`).
- **Rescue.** `rescue-sbtc` / `rescue-token` / `rescue-stx` sweep stray
  balances to the deployer, gated to `tx-sender == DEPLOYER`
  (`ERR-NOT-AUTHORIZED u1002`). The contract holds nothing between calls.

## Deploy

Clarity 5, account 0 (`SPV9K21T…`) — `DEPLOYER` is set from `tx-sender` at
deploy and is the rescue-sweep recipient, so it must be the ops account.
Clarity 6 is rejected by mainnet's tooling pin; the `as-contract?` +
`current-contract` pattern requires Clarity 5 (plain `as-contract` and the
`(define-constant CONTRACT (as-contract tx-sender))` pattern are Clarity 3/4
only).

## Verification

`simulations/verify-mia-arbitrage.cjs` — a self-verifying stxer mainnet-fork
sim: deploys the draft, pumps/dumps the Faktory pool to create real
imbalances, executes all six routes, and cross-checks each XYK/Velar route's
actual output against its `check-*` estimate to the exact unit (diff 0). It
also proves the empty DLMM pool reverts, the wrong-direction guard fires
(`u1001`), rescue auth (`u1002`), and that no dust is left in the contract
(deployer balance delta == sum of every route's output + rescue).

```
NODE_PATH=/path/to/mia-single-faktory/node_modules \
  node simulations/verify-mia-arbitrage.cjs
```

Latest run: **36 passed, 0 failed** —
https://stxer.xyz/simulations/mainnet/53594040b7f1eb1694113463ae725d28
