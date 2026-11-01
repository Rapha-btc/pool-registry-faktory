# stxcity-fee-adapter

fak.fun front door for STX.CITY tokens (AI DAO launches): takes a fee in STX for
fak.fun, then trades for the user in the same tx. Never runs as-contract, never
holds funds; the user's post-conditions bound every transfer.

Source: `contracts/stxcity-fee-adapter.clar`. Deploy bytes (comments stripped,
`clarinet format`): `contracts/d-stxcity-fee-adapter.clar`. NOT deployed.

## Paths

| Function | Venue | Fee | Min-out guard |
|---|---|---|---|
| `buy-curve` | STX.CITY bonding-curve dex `buy` | 1% of STX in | adapter, `u5004` |
| `buy-pool` | Bitflow `xyk-core-v-1-2 swap-x-for-y` | 1% of STX in | Bitflow, `u1020` |
| `sell-pool` | Bitflow `xyk-core-v-1-2 swap-y-for-x` | 1% of STX out | adapter on net after fee, `u5004` |

No curve sell: STX.CITY `sell` asserts `contract-caller == tx-sender`.

Fee: default `u100` bps (1%), owner-settable up to `u300` (3%). If the user is the
fee recipient the fee transfer is skipped.

`sell-pool` passes `u1` as Bitflow's min (Bitflow rejects 0) and checks the user's
`min-stx-out` against what they keep after the fee. `tokens-in u0` is rejected by
Bitflow (`u1002`), so the adapter has no zero check there.

Errors: `u5001` not owner, `u5002` venue not approved, `u5003` zero amount,
`u5004` slippage, `u5005` fee above cap.

## Validation (stxer mainnet fork, 2026-11-01)

`node verify-stxcity-fee-adapter.js`, uses the juice node (no Hiro 429).

- source: **74/74** https://stxer.xyz/simulations/mainnet/ee08145e00f6b98b89c6339cfd2932e8
- deploy bytes, `SRC=./contracts/d-stxcity-fee-adapter.clar node verify-stxcity-fee-adapter.js`:
  **74/74** https://stxer.xyz/simulations/mainnet/534d71db78f9afea0752a4916f9c6c96

Venues: curve `SP2XCME6ED8RERGR9R7YDZW7CA6G3F113Y8JMVA46.canex-stxcity-dex` (not
graduated); pool `SP2XCME6ED8RERGR9R7YDZW7CA6G3F113Y8JMVA46.xyk-pool-stx-aiearn-v-1-1`
(x = `token-stx-v-1-2`, y = `aiearn-stxcity`, core = `xyk-core-v-1-2`, ~811 STX);
user `SP3HXJJMJQ06GNAZ8XWDN1QM48JEDC6PP6W3YZPZJ`.

Covered:
- fee recipient gets exactly 1% on all three paths (sells: 1% of gross STX out)
- user pays/receives exact amounts; adapter holds 0 STX / 0 tokens at all 13 snapshots
- slippage: buy-curve and sell-pool fail `u5004` at achievable+1, pass at achievable;
  buy-pool fails in Bitflow with `u1020`
- unapproved venue `u5002` on all paths (sell-pool checks after the swap; tx rolls back)
- zero amount `u5003` on both buys; sell-pool `tokens-in u0` -> Bitflow `u1002`
- fee `u301` -> `u5005`, `u300` accepted; non-owner setters `u5001`
- two-step owner handover (stranger refused, pending cleared after accept)
- fee recipient == user: no transfer, no failure

`simulations/verify-stxcity-fee-adapter.cjs` is an older harness (0.5% fee, Hiro
reads), superseded by the root `verify-stxcity-fee-adapter.js`.
