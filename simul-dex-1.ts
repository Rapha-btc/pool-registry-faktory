/*
## Dex/Pre Registry Simulation - HAPPY PATH

Tests the pool registry contract with dex and prelaunch operations.
We'll register 2 dex/pre pairs and execute buy/sell + buy-seats/refund operations.
*/

import fs from "node:fs";
import {
  uintCV,
  principalCV,
  stringAsciiCV,
  stringUtf8CV,
  someCV,
  noneCV,
  bufferCV,
  ClarityVersion,
  contractPrincipalCV,
} from "@stacks/transactions";
import { SimulationBuilder } from "stxer";

// Define addresses
const DEPLOYER = "SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM";
const SBTC_USER_1 = "SP2QGMXH21KFDX99PWNB7Z7WNQ92TWFAECEEK10GE"; // Has sBTC ✅
const SBTC_USER_2 = "SP1DZARHA1GVEWVCDF1J9N044A69Q6VT7KMDPQ5N9"; // Has sBTC ✅
const RANDOM_USER = "SP1K1A1PMGW2ZJCNF46NWZWHG8TS1D23EGH1KNK60";

// Token address
const SBTC_TOKEN = "SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token";

// Opcodes
const OP_SWAP_A_TO_B = bufferCV(Buffer.from([0x00]));
const OP_SWAP_B_TO_A = bufferCV(Buffer.from([0x01]));
const OP_ADD_LIQUIDITY = bufferCV(Buffer.from([0x02]));
const OP_REMOVE_LIQUIDITY = bufferCV(Buffer.from([0x03]));

SimulationBuilder.new()
  .withSender(DEPLOYER)

  // ===== DEPLOYMENT =====
  .addContractDeploy({
    contract_name: "faktory-pool-registry",
    source_code: fs.readFileSync(
      "./contracts/faktory-pool-registry.clar",
      "utf8"
    ),
    clarity_version: ClarityVersion.Clarity3,
  })

  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, "(get-last-dex-id)")

  // ===== REGISTER 2 DEX/PRE PAIRS =====

  // Register Bethresen
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "register-dex",
    function_args: [
      principalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.bethresen-faktory-dex"
      ),
      principalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.bethresen-pre-faktory"
      ),
      principalCV("SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token"),
      principalCV("SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.bethresen-faktory"),
      uintCV(21000000),
      uintCV(100000000000000000),
      someCV(uintCV(69000)),
      someCV(uintCV(1000000000000000)),
      uintCV(876543), // creation burn block height
    ],
  })

  // Register Fakoon
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "register-dex",
    function_args: [
      principalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakoon-faktory-dex"
      ),
      principalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakoon-pre-faktory"
      ),
      principalCV("SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token"),
      principalCV("SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakoon-faktory"),
      uintCV(21000000),
      uintCV(100000000000000000),
      someCV(uintCV(69000)),
      someCV(uintCV(1000000000000000)),
      uintCV(876544), // creation burn block height
    ],
  })

  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, "(get-last-dex-id)")

  // ===== ERROR TESTS - Registration =====

  // Try to register duplicate dex
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "register-dex",
    function_args: [
      principalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.bethresen-faktory-dex"
      ),
      principalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.bethresen-pre-faktory"
      ),
      principalCV(SBTC_TOKEN),
      principalCV("SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.bethresen-faktory"),
      uintCV(21000000),
      uintCV(100000000000000000),
      someCV(uintCV(69000)),
      someCV(uintCV(1000000000000000)),
      uintCV(876543),
    ],
  })

  // Unauthorized registration attempt
  .withSender(RANDOM_USER)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "register-dex",
    function_args: [
      principalCV("SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fake-dex"),
      principalCV("SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fake-pre"),
      principalCV(SBTC_TOKEN),
      principalCV("SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fake-token"),
      uintCV(1000000),
      uintCV(1000000000),
      noneCV(),
      noneCV(),
      uintCV(100000),
    ],
  })

  // ===== EDIT DEX =====
  .withSender(DEPLOYER)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "edit-dex",
    function_args: [
      uintCV(1), // Bethresen dex-id
      principalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.bethresen-faktory-dex"
      ),
      principalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.bethresen-pre-faktory"
      ),
      principalCV(SBTC_TOKEN),
      principalCV("SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.bethresen-faktory"),
      uintCV(22000000), // updated x-target
      uintCV(100000000000000000),
      someCV(uintCV(70000)), // updated price
      someCV(uintCV(1000000000000000)),
      uintCV(876543),
    ],
  })

  // Unauthorized edit attempt
  .withSender(RANDOM_USER)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "edit-dex",
    function_args: [
      uintCV(1),
      principalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.bethresen-faktory-dex"
      ),
      principalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.bethresen-pre-faktory"
      ),
      principalCV(SBTC_TOKEN),
      principalCV("SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.bethresen-faktory"),
      uintCV(1000000),
      uintCV(1000000000),
      noneCV(),
      noneCV(),
      uintCV(100000),
    ],
  })

  // Edit non-existent dex
  .withSender(DEPLOYER)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "edit-dex",
    function_args: [
      uintCV(999), // non-existent
      principalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.bethresen-faktory-dex"
      ),
      principalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.bethresen-pre-faktory"
      ),
      principalCV(SBTC_TOKEN),
      principalCV("SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.bethresen-faktory"),
      uintCV(1000000),
      uintCV(1000000000),
      noneCV(),
      noneCV(),
      uintCV(100000),
    ],
  })

  // ===== PRELAUNCH OPERATIONS (Bethresen) =====

  // Buy seats
  .withSender(SBTC_USER_1)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "prelaunch",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "bethresen-pre-faktory"
      ),
      uintCV(5), // buy 5 seats
      noneCV(), // owner defaults to tx-sender
      someCV(OP_ADD_LIQUIDITY),
    ],
  })

  // Refund seats
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "prelaunch",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "bethresen-pre-faktory"
      ),
      uintCV(0), // seat-count ignored for refund
      noneCV(), // refund for tx-sender
      someCV(OP_REMOVE_LIQUIDITY),
    ],
  })

  // Buy seats with explicit owner
  .withSender(SBTC_USER_2)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "prelaunch",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "bethresen-pre-faktory"
      ),
      uintCV(10),
      someCV(principalCV(SBTC_USER_2)),
      someCV(OP_ADD_LIQUIDITY),
    ],
  })

  // ===== DEX OPERATIONS (Fakoon) =====

  // Buy tokens
  .withSender(SBTC_USER_1)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "place-order",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "fakoon-faktory-dex"
      ),
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "fakoon-faktory"
      ),
      uintCV(1000000), // 0.01 sBTC
      someCV(OP_SWAP_A_TO_B),
    ],
  })

  // Sell tokens
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "place-order",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "fakoon-faktory-dex"
      ),
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "fakoon-faktory"
      ),
      uintCV(500000000000000), // 0.5 million tokens
      someCV(OP_SWAP_B_TO_A),
    ],
  })

  // ===== ERROR TESTS - Operations =====

  // Execute on unregistered pre contract
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "prelaunch",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "unregistered-pre"
      ),
      uintCV(1),
      noneCV(),
      someCV(OP_ADD_LIQUIDITY),
    ],
  })

  // Execute on unregistered dex contract
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "place-order",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "unregistered-dex"
      ),
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "some-token"
      ),
      uintCV(1000000),
      someCV(OP_SWAP_A_TO_B),
    ],
  })

  // Invalid operation code for prelaunch
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "prelaunch",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "bethresen-pre-faktory"
      ),
      uintCV(1),
      noneCV(),
      someCV(OP_SWAP_A_TO_B), // invalid for prelaunch
    ],
  })

  // Invalid operation code for place-order
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "place-order",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "fakoon-faktory-dex"
      ),
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "fakoon-faktory"
      ),
      uintCV(1000000),
      someCV(OP_ADD_LIQUIDITY), // invalid for place-order
    ],
  })

  // ===== READ-ONLY TESTS =====
  .withSender(DEPLOYER)
  .addEvalCode(
    `${DEPLOYER}.faktory-pool-registry`,
    `(get-dex-by-contract 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.bethresen-faktory-dex)`
  )
  .addEvalCode(
    `${DEPLOYER}.faktory-pool-registry`,
    `(get-pre-by-contract 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.bethresen-pre-faktory)`
  )
  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, `(get-dex-by-id u1)`)
  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, `(get-dex-by-id u2)`)
  .addEvalCode(
    `${DEPLOYER}.faktory-pool-registry`,
    `(get-dex-by-id u999)` // non-existent
  )
  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, `(get-last-dex-id)`)

  .run()
  .catch(console.error);

/*
Expected Results:

✅ Deploy registry
✅ Register 2 dex/pre pairs (Bethresen, Fakoon)
✅ Duplicate registration fails (ERR_POOL_ALREADY_EXISTS u1002)
✅ Unauthorized registration fails (ERR_NOT_AUTHORIZED u1001)
✅ Edit dex succeeds
✅ Unauthorized edit fails (ERR_NOT_AUTHORIZED u1001)
✅ Edit non-existent fails (ERR_POOL_NOT_FOUND u1003)
✅ Buy seats (prelaunch) succeeds
✅ Refund seats (prelaunch) succeeds
✅ Buy tokens (place-order) succeeds
✅ Sell tokens (place-order) succeeds
✅ Execute unregistered pre fails (ERR_POOL_NOT_FOUND u1003)
✅ Execute unregistered dex fails (ERR_POOL_NOT_FOUND u1003)
✅ Invalid opcode for prelaunch fails (ERR_INVALID_OPERATION u1006)
✅ Invalid opcode for place-order fails (ERR_INVALID_OPERATION u1006)
✅ Lookup from dex-contract succeeds
✅ Lookup from pre-contract succeeds
✅ Lookup by ID succeeds

Total: 2 dex/pre pairs registered, all operations demonstrated!
*/
