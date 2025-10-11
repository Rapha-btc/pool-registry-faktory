# Stacks DEX Arbitrage Router

A high-performance arbitrage execution contract for the Stacks blockchain that enables atomic multi-hop token swaps across 15+ decentralized exchanges to capture cross-DEX price inefficiencies.

## Overview

This contract acts as a universal router that can execute complex arbitrage strategies in a single transaction. By exploiting temporary price discrepancies across different DEXes, users can profit from market inefficiencies.

**Core Concept:** Send 1 STX, receive >1 STX back through optimized cross-DEX routing.

## Key Features

- ✅ **Multi-DEX Support**: Routes trades across 15+ different DEX protocols
- ✅ **Atomic Execution**: All swaps succeed or entire transaction reverts
- ✅ **Profit Guarantee**: Built-in check ensures you receive ≥ your starting amount
- ✅ **Batch Processing**: Execute multiple arbitrage routes in parallel
- ✅ **Gas Optimized**: Compact encoding minimizes transaction costs
- ✅ **Zero-Trust**: No owner privileges or upgrade keys

## Supported DEX Protocols

The contract interfaces with the following Stacks DEXes:

| Protocol           | Version   | Pool Types         | Protocol IDs |
| ------------------ | --------- | ------------------ | ------------ |
| **ALEX**           | v2        | AMM                | `0x00-0x01`  |
| **Velar**          | v1.0.0    | Uniswap V2 style   | `0x02-0x03`  |
| **Velar**          | v1.0.0    | Pools with fees    | `0x04`       |
| **Curve**          | v1.0.0    | Stableswap (ststx) | `0x05`       |
| **Bitflow XYK**    | v1.1      | Constant product   | `0x06-0x07`  |
| **Bitflow XYK**    | v1.2      | Constant product   | `0x08-0x09`  |
| **STX-ststx**      | v1.2      | Stableswap         | `0x0a-0x0b`  |
| **Bitflow Stable** | v1.2      | Stableswap         | `0x0c-0x0d`  |
| **USDA-aeUSDC**    | v1.2/v1.4 | Stableswap         | `0x0e-0x0f`  |
| **Bitflow Stable** | v1.4      | Stableswap         | `0x10-0x11`  |
| **StackSwap**      | v5k       | AMM                | `0x12-0x13`  |
| **Arkadiko**       | v2.1      | AMM                | `0x14-0x15`  |
| **Stacking DAO**   | v4        | Staking deposit    | `0x16`       |
| **Velar Curve**    | v1.1.0    | Curve pools        | `0x17`       |
| **Charisma**       | v0        | Various pools      | `0x18`       |

## How It Works

### Architecture

```
User → sr() → sw() → DEX₁ → sw() → DEX₂ → sw() → DEXₙ → User
     (route)  (hop1)        (hop2)         (hopN)       (profit)
```

### Route Encoding

Each arbitrage route is encoded as a 20-byte buffer:

```
Bytes 0-3:  Route metadata (token indices, amounts)
Bytes 4-7:  Hop 1 instructions
Bytes 8-11: Hop 2 instructions
Bytes 12-15: Hop 3 instructions
Bytes 16-19: Hop 4 instructions
```

**Metadata Structure (first 4 bytes):**

- Byte 0: Protocol ID (0x00-0x19)
- Byte 1: Token A index in registry
- Byte 2: Token B index in registry
- Byte 3: Amount/Pool index (depends on protocol)

### Token Registry

The contract maintains curated lists of tokens:

- **80 standard tokens** (`kft`) - Major Stacks tokens
- **21 ALEX wrapper tokens** (`kaft`) - ALEX-specific tokens
- **31 Velar pool tokens** (`kv2p`)
- **51 StackSwap LP tokens** (`ksbp`)
- **38 Charisma pool tokens** (`kchp`)
- **24+ Bitflow pools** (`kbp1-4`)

## Usage

### Basic Arbitrage Execution

```clarity
;; Execute a single arbitrage route
(contract-call? .arbitrage-router sr 0x[20-byte-route])
```

**Example Route:**

```
STX → USDA (ALEX) → BTC (Velar) → STX (Bitflow)
Input:  1.0 STX
Output: 1.03 STX (3% profit)
```

### Batch Execution

```clarity
;; Execute multiple routes simultaneously
(contract-call? .arbitrage-router ss 0x[400-byte-buffer])
```

The buffer can contain up to 20 different 20-byte routes that execute in parallel.

### Route Construction

To build a route manually:

```clarity
;; Route: STX → USDA → STX (triangular arbitrage)
0x00           ;; Protocol: ALEX AMM
  14           ;; Token A: STX (index 14 in kft)
  0C           ;; Token B: USDA (index 12 in kft)
  00000064     ;; Amount: 100 (in smallest units)

  01           ;; Next hop: ALEX reverse swap
  0C           ;; Token A: USDA
  14           ;; Token B: STX
  00000000     ;; Use available balance
```

## Profit Mechanics

### Arbitrage Conditions

Profitable arbitrage exists when:

```
Price(TokenA→B)[DEX₁] × Price(TokenB→C)[DEX₂] × Price(TokenC→A)[DEX₃] > 1
```

### Real Example Scenario

```
DEX State:
- ALEX:      1 STX = 1.00 USDA
- StackSwap: 1 USDA = 0.000051 BTC
- Velar:     0.000050 BTC = 1.02 STX

Arbitrage Path:
1. Send 1 STX → ALEX → Get 1.00 USDA
2. Send 1.00 USDA → StackSwap → Get 0.000051 BTC
3. Send 0.000051 BTC → Velar → Get 1.02 STX

Net Profit: 0.02 STX (2%)
```

### Protection Mechanism

```clarity
;; Built-in profit check (line ~705)
(asserts! (>= v5 v2) (err u8))
```

This ensures the final token balance ≥ starting amount. If not profitable, transaction reverts.

## Technical Deep Dive

### Function Reference

#### `sr (route: buff 20) → response`

**Single Route Execution**

- Decodes route parameters from 20-byte buffer
- Transfers tokens from user to contract
- Executes swap chain via `sw` function
- Returns tokens to user
- Validates profit was made

**Returns:** Amount of profit earned (in token units)

#### `sw (token: ft, instructions: response) → response`

**Swap Worker Function**

- Called recursively for each hop in the route
- Reads protocol ID and routes to correct DEX
- Executes atomic swap on target DEX
- Passes remaining buffer to next hop

#### `ss (routes: buff 400) → response`

**Batch Processor**

- Splits 400-byte buffer into 20-byte chunks
- Maps `sr` over each route
- Executes all routes in single transaction
- Returns array of profits

#### `r0 (routes: buff 400) → response`

**Alias for `ss`**

Public entry point for batch execution.

### Error Codes

| Code | Meaning                                                        |
| ---- | -------------------------------------------------------------- |
| `u2` | DEX swap failed                                                |
| `u8` | No profit - all tokens consumed                                |
| `u9` | Insufficient profit - some tokens returned but less than input |

### Gas Optimization

The contract uses several techniques to minimize transaction costs:

1. **Compact Encoding**: 20 bytes per route vs verbose JSON
2. **Registry Lookups**: Token addresses stored once, referenced by index
3. **Single Transfer**: User → Contract → User (not per-hop)
4. **Buffer Slicing**: Efficient sub-buffer extraction without copying

## Finding Arbitrage Opportunities

### Off-Chain Discovery

To find profitable routes:

```javascript
// Pseudo-code for arbitrage scanner
async function findArbitrage() {
  const prices = await fetchAllDEXPrices();

  for (const [dex1, dex2, dex3] of dexCombinations) {
    const rate =
      prices[dex1].stx_usda * prices[dex2].usda_btc * prices[dex3].btc_stx;

    if (rate > 1.002) {
      // >0.2% profit (accounting for fees)
      const route = encodeRoute([dex1, dex2, dex3]);
      await executeArbitrage(route);
    }
  }
}
```

### Price Feeds

Monitor these on-chain sources:

- Pool reserves: `get-balances` on each DEX
- Recent swaps: Track swap events
- Pending transactions: Detect large trades that will move prices

### Execution Strategy

1. **Monitor**: Watch all DEX reserves continuously
2. **Calculate**: Compute cross-DEX rates in real-time
3. **Encode**: Build profitable route as 20-byte buffer
4. **Execute**: Call `sr()` with the route
5. **Profit**: Receive tokens + arbitrage gain

## Security Considerations

### Contract Safety

✅ **No Admin Keys**: Contract has no owner privileges  
✅ **No Upgrades**: Immutable deployment  
✅ **Atomic Execution**: All-or-nothing swaps  
✅ **Profit Validation**: Built-in checks prevent losses  
✅ **No Token Custody**: Tokens only held during transaction

### User Risks

⚠️ **Front-Running**: MEV bots may see and copy your transaction  
⚠️ **Slippage**: Large trades can move prices during execution  
⚠️ **Failed Routes**: Route may be unprofitable by execution time  
⚠️ **Gas Costs**: Failed attempts still cost transaction fees

### Best Practices

1. **Simulate First**: Test routes off-chain before submitting
2. **Private Mempool**: Use private relay if available
3. **Small Amounts**: Start with minimal capital to test
4. **Monitor Actively**: Opportunities are fleeting (seconds)
5. **Account for Fees**: Ensure profit > (gas costs + DEX fees)

## Economics

### Fee Structure

Each DEX charges different fees:

- **ALEX**: 0.30%
- **Velar**: 0.30%
- **Bitflow**: 0.25-0.30%
- **StackSwap**: 0.30%
- **Arkadiko**: 0.30%

**Minimum Profitable Arbitrage:**

```
Gross Profit > (Sum of DEX Fees) + (Gas Cost) + (Risk Premium)

Example:
3-hop route = ~0.90% total DEX fees
Gas cost = ~0.10%
Minimum profitable rate = ~1.015x (1.5% gain)
```

### Capital Efficiency

The contract's profit scales with capital:

| Capital    | 1% Arb  | 2% Arb  | 5% Arb  |
| ---------- | ------- | ------- | ------- |
| 100 STX    | 1 STX   | 2 STX   | 5 STX   |
| 1,000 STX  | 10 STX  | 20 STX  | 50 STX  |
| 10,000 STX | 100 STX | 200 STX | 500 STX |

_Note: Large trades may experience slippage_

## Advanced Usage

### Multi-Hop Complex Routes

```clarity
;; 5-hop arbitrage: STX → USDA → BTC → DIKO → ALEX → STX
(contract-call? .arbitrage-router sr
  0x00140C00000064   ;; Hop 1: STX → USDA (ALEX)
  020C0500000000     ;; Hop 2: USDA → BTC (Velar)
  040509FFFFFFFF     ;; Hop 3: BTC → DIKO (Velar fees)
  000910FFFFFFFF     ;; Hop 4: DIKO → ALEX (ALEX)
  011014FFFFFFFF     ;; Hop 5: ALEX → STX (ALEX reverse)
)
```

### Flash Arbitrage Pattern

```clarity
;; 1. Borrow large amount from lending protocol
;; 2. Execute arbitrage with borrowed funds
;; 3. Repay loan + interest
;; 4. Keep profit

(define-public (flash-arbitrage (amount uint) (route (buff 20)))
  (let (
    (borrowed (try! (borrow-flash amount)))
    (profit (try! (contract-call? .router sr route)))
  )
    (try! (repay-flash (+ amount interest)))
    (ok profit)
  )
)
```

### Monitoring & Analytics

Track performance metrics:

```javascript
// Key metrics to monitor
{
  "total_routes_executed": 1523,
  "successful_arbs": 1401,
  "success_rate": "91.9%",
  "total_profit": "1,247 STX",
  "avg_profit_per_route": "0.89 STX",
  "largest_profit": "15.3 STX",
  "gas_costs": "152 STX",
  "net_profit": "1,095 STX"
}
```

## Deployment

```bash
# Deploy contract
clarinet contract deploy arbitrage-router

# Verify deployment
stx call-read-only [contract-address] get-token-count
```

## Testing

```bash
# Run unit tests
clarinet test

# Simulate route
clarinet console
>>> (contract-call? .arbitrage-router sr 0x[route])
```

## Contributing

Contributions welcome! Areas for improvement:

- [ ] Add more DEX integrations
- [ ] Optimize gas usage further
- [ ] Build route discovery bot
- [ ] Create monitoring dashboard
- [ ] Add profit estimation tools

## License

MIT License - See LICENSE file

## Disclaimer

**USE AT YOUR OWN RISK**

- This is experimental DeFi software
- Arbitrage trading carries financial risk
- Past profits don't guarantee future returns
- You may lose your invested capital
- No warranties or guarantees provided
- Always test with small amounts first

## Resources

- [Stacks Docs](https://docs.stacks.co)
- [Clarity Language Reference](https://docs.stacks.co/clarity)
- [ALEX Documentation](https://docs.alexgo.io)
- [Velar Documentation](https://docs.velar.co)
- [Bitflow Documentation](https://docs.bitflow.finance)

## Contact

For questions or support:

- Open an issue on GitHub
- Join the Stacks Discord
- Follow updates on Twitter

---

**Built for the Stacks blockchain ecosystem** 🔥

**Happy arbitraging!** 📈
