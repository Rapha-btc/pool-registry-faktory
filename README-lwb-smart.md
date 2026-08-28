# lwb-smart-faktory

Smart split router for LWB (`SP277HZA8AGXV42MZKDW5B2NNN61RHQ42MTAHVNB1.little-whiny-bitch-stxcity`, asset `LWB`, 6 dec).
Lives in `pool-registry-faktory` as untracked files (not committed). Same public interface as
`fakfun-smart-faktory` / `leo-smart-faktory`, so FE `SMART_TOKENS` + BE `SMART_ROUTERS` only need a config entry.

Target: `SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.lwb-smart-faktory` (Clarity 5). NOT deployed.
On-chain bytes will be `contracts/d-lwb-smart-faktory.clar` (comment-stripped variant).

## Venues (verified on-chain 2026-08-27)

- fak leg: `SPV9K21….lwb-faktory-pool` via `fakfun-core-v2 execute`. Pool is registered
  in core-v2 (pool id lookup ok) and core-v2 is an approved caller of the gated pool.
  Pool family = leo/flatearth: sells return raw `dy` but transfer `dy - 0.1%`, so the
  sell leg keeps the `(- raw-dy (/ raw-dy u1000))` haircut. Buys transfer `dy` exactly.
- dex leg: bitflow `SP277HZA8AGXV42MZKDW5B2NNN61RHQ42MTAHVNB1.xyk-pool-stx-lwb-v-1-1`
  via `xyk-core-v-1-2`. Orientation is `x = STX, y = LWB` (reversed vs fakfun):
  STX->LWB = `swap-x-for-y`, LWB->STX = `swap-y-for-x`; liquidity read = `x-balance`.
  Fees 10/40 bps both sides.
- sBTC<->STX bridge: bitflow sbtc-stx xyk (`flag=true`) or Velar 0070 (`flag=false`).

Liquidity at sim time: fak pool 304,095 sats / 796M LWB; bitflow 1,514 STX / 1.28B LWB.
Optimizer: fak-ratio ~38-42, alex-ratio ~57-61.

## Validation

- `clarinet check`: 1 error, the known stxcity token/dex cycle (`lwb-faktory-pool` unresolved,
  same as FLAT). Everything else compiles. stxer is the real validator.
- `node verify-lwb-smart.js` (stxer mainnet fork, block 8855527): **53/53 green**
  https://stxer.xyz/simulations/mainnet/a79188be36db3d83809ab5066f763fd5
  Deploy Clarity 5, 21 read-onlys, 4 legs x 2 bridges x ratios {0,50,100}, 4 smart-* wrappers,
  zero residue (STX / sBTC / LWB). Uses the juice box API (`STACKS_API`) to dodge Hiro 429.
- `SRC=./contracts/d-lwb-smart-faktory.clar node verify-lwb-smart.js` for the deploy variant.

## Deploy (later)

Same path as fakfun-smart: add a `lwb-smart-faktory-template.ts` (byte-equal to the `d-` file)
to faktory-dao, allowlist it in `/api/bot/deploy-contract`, then
`POST /api/bot/deploy-contract {"contractName":"lwb-smart-faktory"}` with `Bearer CRON_SECRET`.
After deploy: BE `SMART_ROUTERS` + FE `SMART_TOKENS` (assetName `LWB`, 6 dec). Deny-mode PCs must
cover both bridges + `xyk-pool-stx-lwb-v-1-1` (token sender) + `lwb-faktory-pool` (token sender).

## Bug-hunt sims (2026-08-27, from the registry repo)

- `node verify-lwb-smart-negatives.js` -> **68/68** https://stxer.xyz/simulations/mainnet/c0c528b361c099bb224c5f39dbb80594
  ratio=101 -> u1002 (x4); min-out=1e30 -> u1000 (x4 x both bridges); 3 sabotaged twins
  (sBTC fak-leg, token payout, STX dex-leg allowance each 1 unit short) all abort, controls pass;
  parity on all 4 smart-* paths: min-out = exact compare-* best-output passes, +1 reverts u1000;
  dust 1/10 units on every leg either fill or fail cleanly at the venue (bitflow u1019, velar u107,
  xyk u3) with zero residue; 1M sats / 500 STX / 300M LWB sizes clear on both bridges.
- `node verify-lwb-smart-postconditions.mjs` -> **9/9** https://stxer.xyz/simulations/mainnet/1d42cb15e1c81c28135b8dade5b093f2
  raw in-session Clarity 5 deploy, then the 4 smart-* fns x 2 rounds with postConditionMode Deny and
  11 PCs each (user, router, lwb-faktory-pool, xyk-pool-stx-lwb token+ustx, both bridges). This is the
  PC list the FE must ship (SMART_TOKENS dexSenders: xyk-pool-stx-lwb-v-1-1 token+ustx on both flags).
- Note (inherited from template, not LWB-specific): smart-* return `token-out`/`sbtc-out`/`stx-out`
  = the compare-* estimate, not the realised amount; the realised amount is in the inner leg's print.
