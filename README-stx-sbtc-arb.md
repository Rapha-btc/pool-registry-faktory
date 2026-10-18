# stx-sbtc-arbitrage-faktory

`contracts/stx-sbtc-arbitrage-faktory.clar`: atomic STX/sBTC round trips through
the live Jing router `SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.swap-router-sbtc-stx-jing-v5-5`,
which reaches the Jing book, Bitflow DLMM v-1/v-2/v-3, Bitflow XYK and Velar.

- `arb-stx`: STX -> sBTC -> STX. `arb-sbtc`: sBTC -> STX -> sBTC.
- The keeper computes the split off chain (like the jingswap front end): leg 1
  as amounts per venue (adding up to `amount`), leg 2 as shares in basis points
  (adding up to 10000), scaled to the router's `out` from leg 1.
- Leg 2's `out` must be at least `amount + min-profit`, else the call reverts
  with `u1001` and nothing moves. Returns `(ok true)`.
- The contract holds the inventory (fund it with plain transfers); profit stays
  in it.

## Roles (checked on `contract-caller`)

- `keeper`: the hot wallet on the arb box. Can only run arbs, which can only grow
  the inventory, so a stolen keeper key cannot drain it.
- `admin`: meant to be the multisig. `withdraw-stx` / `withdraw-sbtc` (always to
  the admin), `set-keeper`, `set-admin`.
- Both start as the deployer. After deploy: `set-keeper` to the keeper wallet,
  then `set-admin` to the multisig.

Errors: `u1001` no profit, `u1002` not authorized, `u1011` leg-2 shares do not add
up to 10000; router errors pass through (`u3004` leg-1 split != amount).

## Tests

`simulations/verify-stx-sbtc-arbitrage.mjs` on a stxer mainnet fork, 47/47:
roles (keeper / admin hand-over, old admin locked out, keeper cannot withdraw),
bad shares and split, live state (unprofitable routes revert with nothing moved),
a planted Velar gap (600 STX Velar -> Jing, 1,000 STX Velar -> 50/50 XYK+DLMM,
400k sats Jing -> Velar all profit, unreachable min-profit reverts), and the
multisig withdrawing everything. Same 47/47 on the comment-stripped,
clarinet-formatted deploy bytes (5,209 B, sha256 db3890e0...):
https://stxer.xyz/simulations/mainnet/a2245d9abbd917c9ed52889e5f9e5d63

Market scan 2026-10-18: the edge is small today (best path Jing -> Velar,
~0.2-1.5 STX per trip at 200-430 STX), capped by Jing book depth.
