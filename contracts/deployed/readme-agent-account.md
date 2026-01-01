Looking at the contract, here's what the agent can do when each permission is granted:

## PERMISSION_MANAGE_ASSETS (bit 0)

```clarity
(define-private (manage-assets-allowed)
  (or (is-owner) (and (is-agent) (not (is-eq u0 (bit-and (var-get agentPermissions) PERMISSION_MANAGE_ASSETS)))))
)
```

**Functions unlocked:**

- `deposit-stx` - Deposit STX into the account
- `deposit-ft` - Deposit any fungible token into the account
- `withdraw-stx` - Withdraw STX (always goes to ACCOUNT_OWNER)
- `withdraw-ft` - Withdraw approved tokens (always goes to ACCOUNT_OWNER)

---

## PERMISSION_USE_PROPOSALS (bit 1)

```clarity
(define-private (use-proposals-allowed)
  (or (is-owner) (and (is-agent) (not (is-eq u0 (bit-and (var-get agentPermissions) PERMISSION_USE_PROPOSALS)))))
)
```

**Functions unlocked:**

- `create-action-proposal` - Create DAO proposals
- `vote-on-action-proposal` - Vote on DAO proposals
- `veto-action-proposal` - Veto DAO proposals
- `conclude-action-proposal` - Conclude/execute DAO proposals

---

## PERMISSION_APPROVE_REVOKE_CONTRACTS (bit 2)

```clarity
(define-private (approve-revoke-contract-allowed)
  (or (is-owner) (and (is-agent) (not (is-eq u0 (bit-and (var-get agentPermissions) PERMISSION_APPROVE_REVOKE_CONTRACTS)))))
)
```

**Functions unlocked:**

- `approve-contract` - Whitelist a contract (voting, swap, or token) for use
- `revoke-contract` - Remove a contract from whitelist

---

## PERMISSION_BUY_SELL_ASSETS (bit 3)

```clarity
(define-private (buy-sell-assets-allowed)
  (or (is-owner) (and (is-agent) (not (is-eq u0 (bit-and (var-get agentPermissions) PERMISSION_BUY_SELL_ASSETS)))))
)
```

**Functions unlocked:**

- `buy-dao-token` - Buy DAO tokens via approved swap adapter
- `sell-dao-token` - Sell DAO tokens via approved swap adapter

---

## Default permissions

```clarity
(define-constant DEFAULT_PERMISSIONS (+
  PERMISSION_MANAGE_ASSETS              ;; ✅ ON
  PERMISSION_USE_PROPOSALS              ;; ✅ ON
  PERMISSION_APPROVE_REVOKE_CONTRACTS   ;; ✅ ON
))
;; PERMISSION_BUY_SELL_ASSETS is OFF by default!
```

So by default, the agent can:

- ✅ Deposit/withdraw assets
- ✅ Create/vote/veto/conclude DAO proposals
- ✅ Approve/revoke contracts
- ❌ Buy/sell tokens (must be explicitly enabled by owner)

---

## Key security note

Even with all permissions, the agent can ONLY:

1. Withdraw to `ACCOUNT_OWNER` (hardcoded, can't change destination)
2. Use approved contracts (must be in the `ApprovedContracts` map)

The owner always has full access regardless of permission flags.
