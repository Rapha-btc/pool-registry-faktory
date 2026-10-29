# sbtc-usdcx-arbitrage-faktory

`contracts/sbtc-usdcx-arbitrage-faktory.clar`: atomic sBTC/USDCx round trips through
the live Jing router `SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.swap-router-sbtc-usdcx-jing-v5-5`,
which reaches the Jing book (`markets-sbtc-usdcx-jing-v6-4`) and the Bitflow DLMM
sbtc-usdcx pools (ids 1, 2, 17; the router picks the pool). Same shape, roles and
safety model as `stx-sbtc-arbitrage-faktory` (README-stx-sbtc-arb.md on origin/main).

- `arb-usdcx`: USDCx -> sBTC -> USDCx. `arb-sbtc`: sBTC -> USDCx -> sBTC.
- Venues are `{ jing, dlmm }` only. The router has no xyk / Velar venue (a nonzero
  amount there aborts `u3003`), so the contract always passes 0 for them and its
  tuples have no such keys (a 4-key tuple is refused as a type error).
- The keeper computes the split off chain: leg 1 as amounts per venue (adding up
  to `amount`), leg 2 as shares in basis points (adding up to 10000), scaled to the
  router's `out` from leg 1; rounding goes to dlmm when it has a share, else jing.
- Leg 2's `out` must be at least `amount + min-profit`, else the call reverts with
  `u1001` and nothing moves. Returns `(ok true)`.
- The contract holds the inventory (fund it with plain transfers); profit stays in it.
  Any input the router leaves unsold (`unsold`) also stays in the contract.

## Roles (checked on `contract-caller`)

- `keeper`: the hot wallet on the arb box. Can only run arbs, which can only grow
  the inventory, so a stolen keeper key cannot drain it.
- `admin`: meant to be the multisig. `withdraw-usdcx` / `withdraw-sbtc` (always to
  the admin), `set-keeper`, `set-admin`.
- Both start as the deployer. After deploy: `set-keeper` to the keeper wallet,
  then `set-admin` to the multisig. `get-roles` reads both.

Errors: `u1001` no profit, `u1002` not authorized, `u1011` leg-2 shares do not add
up to 10000; router errors pass through (`u3004` leg-1 split != amount, `u3001`
zero amount, e.g. leg 1 sold nothing).

## Tests

`simulations/verify-sbtc-usdcx-arbitrage.mjs` on a stxer mainnet fork (keyless Lazer
via faktory-dao), 92/92: roles (hand-over, old admin locked out, keeper cannot set
admin), refusals on live state (non-keeper, bad shares, bad split, 4-key xyk tuple,
router u3003 for xyk / Velar, DLMM -> DLMM no edge u1001, keeper / stranger / old
deployer cannot withdraw), planted gaps (Jing makers at mid +/-10 bps; whale dumps
0.6 sBTC into DLMM pool 1 -> `arb-usdcx` 500 / 400 (80/20 split) / 400 profit
~5.8 / 2.9 / 4.3 USDCx, leg 2 back into DLMM reverts u1001; whale buys with
100k USDCx -> `arb-sbtc` 0.003 / 0.002 profit ~1,590 / 890 sats; unreachable
min-profit reverts both sides; non-keeper refused during the gap), router keeps
nothing after every call, and the multisig withdrawing everything.
- Source: https://stxer.xyz/simulations/mainnet/106f99bd11b662cb40210db2ac219cf5
- Comment-stripped, clarinet-formatted deploy bytes (4,621 B, sha256 dd2922e8...):
  https://stxer.xyz/simulations/mainnet/a0d8c0379572d6e1921590f9952a8ae4

Run: `node simulations/verify-sbtc-usdcx-arbitrage.mjs` (`SRC=<file>` for other
bytes, `H=<height>` to pin). It reuses `_yg-loop-common.js` / `_lazer.js` from
`../../../../jing-contracts-v3/simulations/` (`JING_HARNESS` overrides).
