# Summary

This registry upgrade enables centralized event logging at the registry level by wrapping pool operations through a single `execute` function, allowing indexers to monitor all swap and liquidity events across registered pools by watching just one contract instead of tracking each pool individually. The implementation requires no changes to existing pool contracts and ANY pool can be registered (including those with burnt LP tokens), though only operations routed through the registry will emit centralized events—direct pool calls will still function but won't be captured by registry-level indexers, so users are encouraged to route transactions through the registry for optimal indexing by STX analytics tools and Dexterity, and migration to new pools that gate calls to pool functions through the registry as caller is also encouraged for guaranteed event capture.

---

# Registry Upgrade README

## Overview

The FakFun Pool Registry has been upgraded to provide **centralized event logging** for all pool operations. This allows indexers, analytics platforms, and frontends to monitor all trading activity across the ecosystem by watching a single registry contract instead of tracking dozens of individual pools.

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

## How It Works

### Registration

Any pool can be registered in the registry, including pools with burnt LP tokens.

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

## Recommendations

1. **Route through registry** for all new integrations
2. **Register all pools** to enable discovery
3. **Update indexers** to watch registry contract
4. **Consider pool gating** for new deployments to guarantee event capture and prevent bypassing
5. **Keep direct pool access** available for power users and emergency scenarios

## Support

For questions or issues with the registry upgrade, please contact the Faktory team or open an issue in the repository.

---

**Version**: 2.0  
**Deployed**: [Add deployment date]  
**Contract**: [Add registry contract address]
