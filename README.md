
# Summary

This registry upgrade enables centralized event logging at the registry level by wrapping pool operations through a single `execute` function, allowing indexers to monitor all swap and liquidity events across registered pools by watching just one contract instead of tracking each pool individually. The implementation requires no changes to existing pool contracts and ANY pool can be registered (including those with burnt LP tokens), though only operations routed through the registry will emit centralized events—direct pool calls will still function but won't be captured by registry-level indexers, so users are encouraged to route transactions through the registry for optimal indexing by STX analytics tools and Dexterity, and migration to new pools that gate calls to pool functions through the registry as caller is also encouraged for guaranteed event capture.

---

# Registry Upgrade README

## Overview

The Faktory Pool Registry has been upgraded to provide **centralized event logging** for all pool operations. This allows indexers, analytics platforms, and frontends to monitor all trading activity across the ecosystem by watching a single registry contract instead of tracking dozens of individual pools.

## What's New

### Centralized Event Logging

The registry now emits standardized events for **registered pool operations**:

- `buy` - Swap token A for token B
- `sell` - Swap token B for token A
- `add-liquidity` - Add liquidity to pools
- `remove-liquidity` - Remove liquidity from pools
- `register-pool` - Pool registration (now includes initial reserves)

### Single Execute Wrapper

A new `execute(pool-contract, amount, opcode)` function routes operations through the registry:

- Checks if pool is registered (fails with error if not)
- Calls the underlying pool to execute the operation
- Captures the result
- Emits a standardized event with pool metadata
- Returns the execution result

**Note:** Only registered pools can be used via registry. Unregistered pools must be called directly.

## Benefits

✅ **For Indexers**: Monitor all registered pools by watching one contract  
✅ **For Analytics**: Unified event schema across all registered pools  
✅ **For Frontends**: Easy integration with registry routing  
✅ **For Pool Owners**: No code changes required—any pool can be registered  
✅ **For LP Burnt Pools**: Can be registered and tracked without migration  
✅ **For Legacy Pools**: Works with existing pools without requiring upgrades

## Security Model

### What Registry Admins Can Do

The registry deployer (admin) has limited control over pool metadata:

- **Edit pool metadata** via `edit-pool`: Can modify displayed pool names, symbols, token addresses, URIs, fee information, and creation height in the registry
- **Register new pools**: Add pools to the registry directory

### What Registry Admins CANNOT Do

❌ **Steal user funds**: The registry never holds user tokens—all transfers happen directly between users and pools  
❌ **Redirect swaps to malicious contracts**: Users explicitly pass the pool contract address they want to interact with, and the registry calls that exact contract  
❌ **Modify pool logic**: Pool contracts are immutable; the registry only wraps calls to them  
❌ **Intercept token transfers**: All token flows bypass the registry entirely  
❌ **Reassign pool contract mappings**: Once a pool contract is registered to a pool ID, that relationship is permanent and immutable (see Immutability section below)

### The Real Risk: Information Integrity

If a registry admin account is compromised, the attacker could:

- **Corrupt event data**: Modify pool metadata so emitted events show wrong token addresses
- **Mislead indexers**: Analytics platforms reading registry events would display incorrect data
- **Confuse users**: Frontends might show wrong pool information

**Important**: Even with corrupted metadata, actual fund transfers execute correctly because they happen at the pool level, not the registry level. This is an **information integrity** issue, not a **fund security** issue.

### Mitigation Strategy

Indexers and frontends should verify registry event data against on-chain pool state:

```javascript
// Example verification
const eventTokens = registryEvent.data.x_token;
const actualPool = await pool.getPool();
if (eventTokens !== actualPool.x_token) {
  console.warn("Registry metadata mismatch detected");
}
```


For critical operations, always cross-reference registry data with direct pool queries.

## Pool Contract Immutability

### Permanent Pool-ID Mappings

Once a pool contract is registered, its relationship to its pool ID is **permanently immutable**:

```clarity
;; This mapping is set once and never changes
(define-map pool-contracts principal uint)  ;; contract → pool-id
```

**What this means:**

- Pool contract `SPxxx...pool-1` registered as pool-id `u5`
- The `edit-pool` function can modify metadata (name, symbol, tokens, etc.)
- BUT: The contract-to-ID mapping `SPxxx...pool-1 → u5` is permanent
- You cannot reassign that contract to a different pool-id
- You cannot assign a different contract to pool-id `u5`

**Why this design?**

This immutability prevents:

- Contract substitution attacks (swapping a malicious contract under a trusted pool ID)
- Registry confusion (same contract appearing under multiple IDs)
- ID recycling issues (reusing pool IDs for different contracts)

**Practical implications:**

- If you deploy a new version of a pool, it needs a new pool ID
- The old pool-id will always point to the original contract
- `edit-pool` is for correcting metadata errors, not migrating contracts
- Pool contract addresses are the source of truth, not the registry metadata

## Testing & Validation

### Comprehensive Unit Tests

The registry has been thoroughly tested using **Stxer** simulation framework against mainnet state. All tests passed successfully:

🟢 **[View complete test suite on Stxer](https://stxer.xyz/simulations/mainnet/5fcdf699654f4071fef8ec25d045b35d)**

### Test Coverage

**Registration Tests:**

- ✅ Register 4 real mainnet pools (LEO, B, sBTC-FakFun, PEPE)
- ✅ Duplicate registration fails with `ERR_POOL_ALREADY_EXISTS` (u1002)
- ✅ Unauthorized registration fails with `ERR_NOT_AUTHORIZED` (u1001)
- ✅ Empty pool name fails with `ERR_INVALID_POOL_DATA` (u1004)
- ✅ Empty pool symbol fails with `ERR_INVALID_POOL_DATA` (u1004)

**Execution Tests (All 4 pools tested):**

- ✅ `OP_SWAP_A_TO_B` (Buy) - Swap sBTC for tokens
- ✅ `OP_SWAP_B_TO_A` (Sell) - Swap tokens for sBTC
- ✅ `OP_ADD_LIQUIDITY` - Add liquidity to pools
- ✅ `OP_REMOVE_LIQUIDITY` - Remove liquidity from pools

**Error Handling Tests:**

- ✅ Execute on unregistered pool fails with `ERR_POOL_NOT_FOUND` (u1003)
- ✅ Invalid opcode handling
- ✅ Default opcode behavior (defaults to buy)

**Query Tests:**

- ✅ `get-pool-by-contract` returns correct pool data with reserves
- ✅ `get-pool-by-id` returns correct pool data
- ✅ `get-last-pool-id` returns accurate count
- ✅ Queries for non-existent pools return `none`

### Test Methodology

Tests simulate real mainnet conditions:

- Uses actual deployed pool contracts
- Tests with real users who hold sBTC tokens
- Validates against mainnet state at block height 4097299
- Covers both happy path and error scenarios
- Verifies event emission and data integrity

**Run tests locally:**

```bash
npm install stxer @stacks/transactions
node simulate.js
```

## How It Works

### Registration

Any Dexterity pool can be registered in the registry, including pools with burnt LP tokens.

### Event Emission Logic

```
User → Registry.execute(pool, amount, opcode)
  ↓
  Registry checks: Is pool registered?
  ↓
  YES → Execute on pool + Emit event with metadata
  NO  → Fail with ERR_POOL_NOT_FOUND
  ↓
  Return result
```

### Direct Pool Calls (Bypass Registry)

```
User → Pool.execute(amount, opcode)
  ↓
  Pool executes operation
  Pool emits its own event
  Registry has no visibility ❌
```

**Important:** Current pools do not restrict direct calls. Users can choose to route through registry (recommended) or call pools directly (still works, but bypasses registry logging).

## Migration Path

### Phase 1: Deploy & Register (Immediate)

1. Deploy upgraded registry contract
2. Register all existing pools (including LP burnt pools)
3. Indexers update to watch registry contract

### Phase 2: Frontend Migration (Recommended)

Update frontend calls from:

```javascript
// Old: Direct pool call
pool.execute(amount, opcode);
```

To:

```javascript
// New: Registry routing
registry.execute(pool, amount, opcode);
```

### Phase 3: Pool Gating (Recommended - Future)

For new pools, add access control to enforce registry routing:

```clarity
;; Only allow calls from registry or approved routers
(asserts! (or
    (is-eq contract-caller REGISTRY)
    (is-approved-caller contract-caller)
) ERR_UNAUTHORIZED)
```

This guarantees all operations are logged at the registry level.

## Backward Compatibility

**No Breaking Changes:**

- Existing pools work without modification
- Direct pool calls continue to function
- Pool-level events still emit
- Any pool can be registered

**Trade-off:**

- Direct pool calls bypass registry logging
- Events from direct calls won't appear in registry event stream
- STX analytics tools and Dexterity won't capture direct trades

## Usage Examples

### Register a Pool

```clarity
(contract-call? .registry register-pool
    .sbtc-leo-pool
    "sBTC-leo"
    "sBTC-leo"
    .sbtc-token
    .leo-token
    block-height
    u10000  ;; 1% LP fee
    (some u"https://faktory.fun/pool/sbtc-leo")
)
```

### Execute Swap via Registry

```clarity
;; Buy (swap A to B)
(contract-call? .registry execute
    .sbtc-leo-pool
    u1000000  ;; amount
    (some 0x00)  ;; opcode for buy
)

;; Sell (swap B to A)
(contract-call? .registry execute
    .sbtc-leo-pool
    u1000000
    (some 0x01)  ;; opcode for sell
)
```

### Query Pool Info

```clarity
(contract-call? .registry get-pool .sbtc-leo-pool)
;; Returns: pool metadata + current reserves
```

## Event Structure

All events include standardized fields for easy indexing:

```clarity
{
    type: "buy",  // or "sell", "add-liquidity", "remove-liquidity"
    sender: principal,
    token-in: principal,
    amount-in: uint,
    token-out: principal,
    amount-out: uint,
    pool-reserves: {dx: uint, dy: uint, dk: uint},
    pool-contract: principal,
    min-y-out: uint
}
```

## For Developers

### Indexer Setup

Watch the registry contract for all events:

```javascript
const registryAddress = "SP123...registry";
const events = await watchContract(registryAddress);
// All registered pool activity routed through registry
```

### Router Integration (Rozar, etc.)

Multi-hop routers can route through registry for automatic logging:

```clarity
(contract-call? .registry execute .pool1 amount1 (some 0x00))
(contract-call? .registry execute .pool2 amount2 (some 0x01))
```

### Analytics Platforms

Query registry events for:

- Volume tracking across all pools
- Price discovery and charting
- Liquidity depth monitoring
- Fee revenue calculations

## Technical Details

- **Opcode System**: Uses buffer-based opcodes (0x00-0x04) for operation types
- **Trait-based**: Works with any pool implementing `liquidity-pool-trait`
- **Gas Efficient**: Single cross-contract call to pool + event emission
- **Registration Required**: Only registered pools can be used via registry
- **Conditional Logging**: Emits events for all registry-routed operations
- **Immutable Mappings**: Pool contract-to-ID relationships are permanent once set

## Recommendations

1. **Route through registry** for all new integrations
2. **Register all pools** to enable discovery
3. **Update indexers** to watch registry contract
4. **Verify registry metadata** against on-chain pool state for critical operations
5. **Consider pool gating** for new deployments to guarantee event capture and prevent bypassing
6. **Keep direct pool access** available for power users and emergency scenarios
7. **Remember immutability**: Pool contract addresses are permanent—deploy new pools for upgrades

## Support

For questions or issues with the registry upgrade, please contact the Faktory team or open an issue in the repository.

---

**Version**: 2.0  
**Deployed**: [Add deployment date]  
**Contract**: [Add registry contract address]  
**Tests**: [All tests passing on Stxer](https://stxer.xyz/simulations/mainnet/2b6c08fefccc690463508ced610ac6ce)

```

```
