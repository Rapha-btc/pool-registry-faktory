# RV (Rendezvous) fuzz harness — mia-smart-faktory

Property-based fuzzing of the deployed `SPV9K21….mia-smart-faktory` router.

## What it fuzzes

`contracts/mia-smart-faktory.clar` here is a **testable twin**: the deployed
source with every mainnet principal rewritten to a local mock (`.mock-*`) and
the principal constants inlined to literals — simnet's static analysis rejects a
*constant* in a trait-arg position (the mainnet node accepts it, which is why the
real contract deploys), so the twin uses literals. The `test-*` property
functions are appended at the bottom.

The mocks are compile-only stubs: they satisfy the venue signatures so the twin
type-checks, but the fuzzed properties (`test-*-ratio-guard`) revert at the
ratio guard **before** any venue call, so mock fidelity is irrelevant to them.

## Properties (all `test-` = property-based)

- `test-buy-sbtc-ratio-guard`, `test-buy-stx-ratio-guard`,
  `test-sell-sbtc-ratio-guard`, `test-sell-stx-ratio-guard`,
  `test-buy-sbtc-dlmm-ratio-guard`: for any fuzzed `(amount, ratio)` with
  `ratio > 100`, the entry point returns **exactly** `ERR-INVALID-RATIO` (u1002)
  — never an arithmetic-overflow panic from `(* amount ratio)`, never a silent
  underflow. This is the exact bug class that once made `ERR-INVALID-RATIO`
  unreachable (see README-mia-smart §4); RV re-verifies it across the input space.

## Run

```
node <path-to>/rendezvous/dist/app.js . mia-smart-faktory test --runs=200
```

**Result: 200 runs, 0 failures** (2026-08-20). 160 property calls passed, 40
discarded (ratio ≤ 100 needs live venues — covered by the stxer conservation
harness instead).

## Scope note

Full end-to-end conservation / split-optimality is *not* fuzzed here: the router
holds no state and its meaningful properties depend on the venues actually moving
tokens (with wrapped-STX semantics only the real contracts implement). Those are
covered with higher fidelity by `verify-mia-smart-coverage.js` against the **real
mainnet pools** (stxer fork). RV here targets the venue-independent guard/arithmetic
layer, where mocks are sound.
