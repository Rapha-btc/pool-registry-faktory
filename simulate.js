/*
## Pool Registry Stxer Simulation

This simulation tests the pool registry contract which manages FakFun and Charisma liquidity pools.

## Installation and Setup

1. Install dependencies:
   npm install stxer @stacks/transactions

2. Add "type": "module" to your package.json

3. Save this as simulate-registry.js

4. Run the simulation:
   node simulate-registry.js

## What this tests:
- Deploying the pool registry
- Registering pools (authorized and unauthorized)
- Editing pool metadata
- Looking up pools by ID and contract address
- Executing operations through the registry (swaps, liquidity)
- Error handling for duplicate pools, unauthorized access, etc.
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
const USER_1 = "SP2QGMXH21KFDX99PWNB7Z7WNQ92TWFAECEEK10GE";
const USER_2 = "SP3GS0VZBE15D528128G7FN3HXJQ20BXCG4CNPG64";
const POOL_DEPLOYER = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22";

// Pool contract addresses (using real deployed pools as examples)
const POOL_1 = `${POOL_DEPLOYER}.bob-faktory-pool`;
const POOL_2 = `${POOL_DEPLOYER}.another-faktory-pool`;

// Token addresses
const TOKEN_X =
  "SP2VG7S0R4Z8PYNYCAQ04HCBX1MH75VT11VXCWQ6G.built-on-bitcoin-stxcity";
const TOKEN_Y = `${DEPLOYER}.sbtc-token`;

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

  // Check initial state - should have no pools
  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, "(get-last-pool-id)")

  // ===== POOL REGISTRATION =====

  // TEST 1: Register first pool (should succeed - deployer is authorized)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "register-pool",
    function_args: [
      contractPrincipalCV(POOL_DEPLOYER, "bob-faktory-pool"),
      stringAsciiCV("BOB-sBTC LP"),
      stringAsciiCV("BOB-SBTC"),
      principalCV(TOKEN_X),
      principalCV(TOKEN_Y),
      uintCV(150000), // creation-height
      uintCV(30), // lp-fee (0.30%)
      someCV(stringUtf8CV("https://faktory.fun/pool/bob-sbtc")),
    ],
  })

  // Check pool was registered
  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, "(get-last-pool-id)")
  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, "(get-pool-by-id u1)")

  // TEST 2: Try to register same pool again (should fail - ERR_POOL_ALREADY_EXISTS)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "register-pool",
    function_args: [
      contractPrincipalCV(POOL_DEPLOYER, "bob-faktory-pool"),
      stringAsciiCV("BOB-sBTC LP Duplicate"),
      stringAsciiCV("BOB-SBTC-2"),
      principalCV(TOKEN_X),
      principalCV(TOKEN_Y),
      uintCV(150000),
      uintCV(30),
      noneCV(),
    ],
  })

  // TEST 3: Non-deployer tries to register pool (should fail - ERR_NOT_AUTHORIZED)
  .withSender(USER_1)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "register-pool",
    function_args: [
      contractPrincipalCV(POOL_DEPLOYER, "another-faktory-pool"),
      stringAsciiCV("Another Pool"),
      stringAsciiCV("ANOTHER"),
      principalCV(TOKEN_X),
      principalCV(TOKEN_Y),
      uintCV(150100),
      uintCV(25),
      noneCV(),
    ],
  })

  // TEST 4: Register second pool with empty name (should fail - ERR_INVALID_POOL_DATA)
  .withSender(DEPLOYER)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "register-pool",
    function_args: [
      contractPrincipalCV(POOL_DEPLOYER, "another-faktory-pool"),
      stringAsciiCV(""), // Empty name
      stringAsciiCV("ANOTHER"),
      principalCV(TOKEN_X),
      principalCV(TOKEN_Y),
      uintCV(150100),
      uintCV(25),
      noneCV(),
    ],
  })

  // TEST 5: Register second pool with empty symbol (should fail - ERR_INVALID_POOL_DATA)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "register-pool",
    function_args: [
      contractPrincipalCV(POOL_DEPLOYER, "another-faktory-pool"),
      stringAsciiCV("Another Pool"),
      stringAsciiCV(""), // Empty symbol
      principalCV(TOKEN_X),
      principalCV(TOKEN_Y),
      uintCV(150100),
      uintCV(25),
      noneCV(),
    ],
  })

  // TEST 6: Register second pool properly (should succeed)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "register-pool",
    function_args: [
      contractPrincipalCV(POOL_DEPLOYER, "another-faktory-pool"),
      stringAsciiCV("FUN-sBTC LP"),
      stringAsciiCV("FUN-SBTC"),
      principalCV(TOKEN_Y),
      principalCV(TOKEN_X),
      uintCV(150200),
      uintCV(25),
      noneCV(), // Will use default URI
    ],
  })

  // Check second pool was registered
  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, "(get-last-pool-id)")
  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, "(get-pool-by-id u2)")

  // ===== POOL LOOKUP TESTS =====

  // TEST 7: Look up pool by contract address
  .addEvalCode(
    `${DEPLOYER}.faktory-pool-registry`,
    `(get-pool-by-contract '${POOL_1})`
  )

  // TEST 8: Look up non-existent pool (should return none)
  .addEvalCode(
    `${DEPLOYER}.faktory-pool-registry`,
    `(get-pool-by-contract '${DEPLOYER}.nonexistent-pool)`
  )

  // TEST 9: Look up non-existent pool ID (should return none)
  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, "(get-pool-by-id u999)")

  // ===== POOL EDITING TESTS =====

  // TEST 10: Edit pool metadata (should succeed - deployer is authorized)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "edit-pool",
    function_args: [
      uintCV(1),
      contractPrincipalCV(POOL_DEPLOYER, "bob-faktory-pool"),
      stringAsciiCV("BOB-sBTC LP v2"),
      stringAsciiCV("BOB-SBTC-V2"),
      principalCV(TOKEN_X),
      principalCV(TOKEN_Y),
      uintCV(150000),
      uintCV(35), // Changed fee
      someCV(stringUtf8CV("https://faktory.fun/pool/bob-sbtc-v2")),
    ],
  })

  // Check pool was edited
  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, "(get-pool-by-id u1)")

  // TEST 11: Non-deployer tries to edit pool (should fail - ERR_NOT_AUTHORIZED)
  .withSender(USER_2)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "edit-pool",
    function_args: [
      uintCV(1),
      contractPrincipalCV(POOL_DEPLOYER, "bob-faktory-pool"),
      stringAsciiCV("Hacked Pool"),
      stringAsciiCV("HACKED"),
      principalCV(TOKEN_X),
      principalCV(TOKEN_Y),
      uintCV(150000),
      uintCV(100),
      noneCV(),
    ],
  })

  // TEST 12: Edit non-existent pool (should fail - ERR_POOL_NOT_FOUND)
  .withSender(DEPLOYER)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "edit-pool",
    function_args: [
      uintCV(999),
      contractPrincipalCV(POOL_DEPLOYER, "bob-faktory-pool"),
      stringAsciiCV("Ghost Pool"),
      stringAsciiCV("GHOST"),
      principalCV(TOKEN_X),
      principalCV(TOKEN_Y),
      uintCV(150000),
      uintCV(30),
      noneCV(),
    ],
  })

  // TEST 13: Edit with empty name (should fail - ERR_INVALID_POOL_DATA)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "edit-pool",
    function_args: [
      uintCV(1),
      contractPrincipalCV(POOL_DEPLOYER, "bob-faktory-pool"),
      stringAsciiCV(""), // Empty name
      stringAsciiCV("BOB-SBTC"),
      principalCV(TOKEN_X),
      principalCV(TOKEN_Y),
      uintCV(150000),
      uintCV(30),
      noneCV(),
    ],
  })

  // ===== GET-POOL FUNCTION TESTS =====

  // TEST 14: Get pool with reserves using get-pool function
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "get-pool",
    function_args: [contractPrincipalCV(POOL_DEPLOYER, "bob-faktory-pool")],
  })

  // TEST 15: Get non-existent pool (should return (ok none))
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "get-pool",
    function_args: [contractPrincipalCV(DEPLOYER, "nonexistent-pool")],
  })

  // ===== EXECUTE FUNCTION TESTS =====

  // TEST 16: Execute swap A to B through registry
  .withSender(USER_1)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(POOL_DEPLOYER, "bob-faktory-pool"),
      uintCV(1000000), // amount
      someCV(OP_SWAP_A_TO_B),
    ],
  })

  // TEST 17: Execute swap B to A through registry
  .withSender(USER_2)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(POOL_DEPLOYER, "bob-faktory-pool"),
      uintCV(500000),
      someCV(OP_SWAP_B_TO_A),
    ],
  })

  // TEST 18: Execute add liquidity through registry
  .withSender(USER_1)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(POOL_DEPLOYER, "bob-faktory-pool"),
      uintCV(2000000),
      someCV(OP_ADD_LIQUIDITY),
    ],
  })

  // TEST 19: Execute remove liquidity through registry
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(POOL_DEPLOYER, "bob-faktory-pool"),
      uintCV(1000000),
      someCV(OP_REMOVE_LIQUIDITY),
    ],
  })

  // TEST 20: Execute on unregistered pool (should fail - ERR_POOL_NOT_FOUND)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(DEPLOYER, "unregistered-pool"),
      uintCV(1000000),
      someCV(OP_SWAP_A_TO_B),
    ],
  })

  // TEST 21: Execute with default opcode (no opcode provided)
  .withSender(USER_2)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(POOL_DEPLOYER, "bob-faktory-pool"),
      uintCV(100000),
      noneCV(), // Will use default 0x00
    ],
  })

  // ===== FINAL STATE CHECKS =====

  // Check final registry state
  .withSender(DEPLOYER)
  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, "(get-last-pool-id)")
  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, "(get-pool-by-id u1)")
  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, "(get-pool-by-id u2)")

  // Summary of all registered pools
  .addEvalCode(
    `${DEPLOYER}.faktory-pool-registry`,
    `(list (get-pool-by-id u1) (get-pool-by-id u2))`
  )

  .run()
  .catch(console.error);

/*
Expected Results Summary:

✅ TEST 1: Register first pool - SUCCESS
✅ TEST 2: Duplicate pool registration - FAIL (ERR_POOL_ALREADY_EXISTS u1002)
✅ TEST 3: Unauthorized registration - FAIL (ERR_NOT_AUTHORIZED u1001)
✅ TEST 4: Empty pool name - FAIL (ERR_INVALID_POOL_DATA u1004)
✅ TEST 5: Empty pool symbol - FAIL (ERR_INVALID_POOL_DATA u1004)
✅ TEST 6: Register second pool - SUCCESS
✅ TEST 7: Lookup by contract - Returns pool info
✅ TEST 8: Lookup non-existent - Returns none
✅ TEST 9: Lookup invalid ID - Returns none
✅ TEST 10: Edit pool metadata - SUCCESS
✅ TEST 11: Unauthorized edit - FAIL (ERR_NOT_AUTHORIZED u1001)
✅ TEST 12: Edit non-existent pool - FAIL (ERR_POOL_NOT_FOUND u1003)
✅ TEST 13: Edit with empty name - FAIL (ERR_INVALID_POOL_DATA u1004)
✅ TEST 14: Get pool with reserves - SUCCESS
✅ TEST 15: Get non-existent pool - Returns (ok none)
✅ TEST 16-19: Execute operations - SUCCESS (emits appropriate events)
✅ TEST 20: Execute on unregistered pool - FAIL (ERR_POOL_NOT_FOUND u1003)
✅ TEST 21: Execute with default opcode - SUCCESS

Total pools registered: 2
Last pool ID: u2
*/
