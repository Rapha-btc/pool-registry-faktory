# PEPE Arbitrage Faktory v2

## Contract

`SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.pepe-arbitrage-faktory-v2`

## Changes from v1

1. **Routes through fakfun-core-v2** — emits print events the backend records via chainhooks
2. **Uses new pool** — `pepe-faktory-pool-v2-2` instead of `pepe-faktory-pool-v2`
3. **Keeps profits** — no SAINT burn, PEPE profits sent to DEPLOYER
4. **8 routes** — added 4 Bitflow PEPE-STX routes (v1 had 4 Velar PEPE-STX only)
5. **FAKTORY_FEE adjustment** — `swap-pepe-to-sbtc` returns `dy * 999/1000` (actual sBTC received after 0.1% protocol fee)
6. **Slippage protection** — all arb functions take `min-pepe-out` parameter

## Routes

| # | Function | Direction | Path |
|---|----------|-----------|------|
| 1 | `arb-fak-bit-vel` | sell-buy | PEPE → sBTC (Faktory) → STX (Bitflow) → PEPE (Velar) |
| 2 | `arb-fak-vel-vel` | sell-buy | PEPE → sBTC (Faktory) → STX (Velar) → PEPE (Velar) |
| 3 | `arb-vel-bit-fak` | buy-sell | PEPE → STX (Velar) → sBTC (Bitflow) → PEPE (Faktory) |
| 4 | `arb-vel-vel-fak` | buy-sell | PEPE → STX (Velar) → sBTC (Velar) → PEPE (Faktory) |
| 5 | `arb-fak-bit-bit` | sell-buy | PEPE → sBTC (Faktory) → STX (Bitflow) → PEPE (Bitflow) |
| 6 | `arb-fak-vel-bit` | sell-buy | PEPE → sBTC (Faktory) → STX (Velar) → PEPE (Bitflow) |
| 7 | `arb-bit-bit-fak` | buy-sell | PEPE → STX (Bitflow) → sBTC (Bitflow) → PEPE (Faktory) |
| 8 | `arb-bit-vel-fak` | buy-sell | PEPE → STX (Bitflow) → sBTC (Velar) → PEPE (Faktory) |

**sell-buy**: starts with Faktory sell (PEPE → sBTC), ends with DEX buy
**buy-sell**: starts with DEX sell (PEPE → STX), ends with Faktory buy (sBTC → PEPE)

> Buy-sell routes (3, 4, 7, 8) require core-v2 gating whitelist for the arb contract.

## FAKTORY_FEE handling

The faktory pool v2-2 `get-swap-quote` handles fees asymmetrically:

- **A-to-B (sBTC → PEPE, opcode 0x00)**: `fee-in` deducted from sBTC input before quote. The returned `dy` is the actual PEPE received. No external adjustment needed.
- **B-to-A (PEPE → sBTC, opcode 0x01)**: `fee-in = 0`, returned `dy` is the **raw** sBTC output. FAKTORY_FEE (1/1000) is skimmed from the actual transfer. The contract receives `dy * 999/1000`.

The `swap-pepe-to-sbtc` helper applies `(/ (* (get dy result) u999) u1000)` so downstream swaps use the correct balance.

## Simulation

Stxer mainnet fork simulation (block 6,697,297):
https://stxer.xyz/simulations/mainnet/7262ac049354491e6e01484106186936

**Results at 1M PEPE (u1000000000):**

| Route | Output | Profit | Status |
|-------|--------|--------|--------|
| fak-bit-vel | 1,099,469,277 | +9.9% | OK |
| fak-vel-vel | 1,099,190,294 | +9.9% | OK |
| vel-bit-fak | — | — | err u1001 (core-v2 gating) |
| vel-vel-fak | — | — | err u1001 (core-v2 gating) |
| fak-bit-bit | 1,089,438,814 | +8.9% | OK |
| fak-vel-bit | 1,087,928,814 | +8.8% | OK |
| bit-bit-fak | — | — | err u1001 (core-v2 gating) |
| bit-vel-fak | — | — | err u1001 (core-v2 gating) |

All sell-buy routes execute successfully. Buy-sell routes need deployer to whitelist the arb contract on core-v2.

## Pool Addresses

| Pool | Contract |
|------|----------|
| PEPE token | `SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz` |
| Faktory pool | `SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.pepe-faktory-pool-v2-2` |
| Faktory core-v2 | `SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-core-v2` |
| Bitflow sBTC-STX | `SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1` |
| Velar sBTC-STX | `SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070` |
| Velar PEPE-STX | Router pool ID u11 |
| Bitflow PEPE-STX | `SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-pepe-stx-v-1-1` |

## Backend Bot

Updated in `backend/faktory-be/server/routes/api/bot/check-arb-opportunities.ts`:
- Contract: `pepe-arbitrage-faktory-v2` (was `pepe-arbitrage-faktory`)
- Routes: 8 (was 4) — added `check-fak-bit-bit`, `check-fak-vel-bit`, `check-bit-bit-fak`, `check-bit-vel-fak`
- Pool conflict map updated for new routes
