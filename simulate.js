/*
## Pool Registry Stxer Simulation - HAPPY PATH

This simulation tests the pool registry contract with realistic scenarios.
We'll register 4 real pools and execute operations on each with proper setup.

## Installation and Setup

1. Install dependencies:
   npm install stxer @stacks/transactions

2. Add "type": "module" to your package.json

3. Save this as simulate.js

4. Run the simulation:
   node simulate.js
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

// Define addresses - using users that actually have sBTC
const DEPLOYER = "SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM";
const SBTC_USER_1 = "SP2QGMXH21KFDX99PWNB7Z7WNQ92TWFAECEEK10GE"; // Has sBTC
const SBTC_USER_2 = "SP3GS0VZBE15D528128G7FN3HXJQ20BXCG4CNPG64"; // Has sBTC
const SBTC_USER_3 = "SP2YS61K9JB3AR06S68JVFMFY4NFBE71EVF9T0R02"; // Has sBTC
const RANDOM_USER = "SP1K1A1PMGW2ZJCNF46NWZWHG8TS1D23EGH1KNK60"; // Random user

// Real deployed pool contracts
const LEO_POOL = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.leo-faktory-pool";
const B_POOL = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory-pool";
const SBTC_POOL =
  "SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS.sbtc-fakfun-amm-lp-v1";
const PEPE_POOL = "SP6SA6BTPNN5WDAWQ7GWJF1T5E2KWY01K9SZDBJQ.pepe-faktory-pool";
const BOB_POOL = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.bob-faktory-pool"; // For unregistered test

// Token addresses
const TOKEN_X = "SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9.token-wstx";
const TOKEN_Y = "SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9.token-wleo";

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

  // Check initial state
  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, "(get-last-pool-id)")

  // ===== REGISTER 4 REAL POOLS =====

  // Register LEO pool
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "register-pool",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "leo-faktory-pool"
      ),
      stringAsciiCV("LEO-STX LP"),
      stringAsciiCV("LEO-STX"),
      principalCV("SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9.token-wleo"),
      principalCV("SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9.token-wstx"),
      uintCV(150000),
      uintCV(30),
      someCV(stringUtf8CV("https://faktory.fun/pool/leo")),
    ],
  })

  // Register B pool
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "register-pool",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "b-faktory-pool"
      ),
      stringAsciiCV("B-STX LP"),
      stringAsciiCV("B-STX"),
      principalCV("SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9.token-wb"),
      principalCV("SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9.token-wstx"),
      uintCV(150100),
      uintCV(30),
      someCV(stringUtf8CV("https://faktory.fun/pool/b")),
    ],
  })

  // Register sBTC pool
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "register-pool",
    function_args: [
      contractPrincipalCV(
        "SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS",
        "sbtc-fakfun-amm-lp-v1"
      ),
      stringAsciiCV("sBTC-FakFun LP"),
      stringAsciiCV("SBTC-FAK"),
      principalCV("SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9.token-wsbtc"),
      principalCV("SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9.token-fakfun"),
      uintCV(150200),
      uintCV(25),
      someCV(stringUtf8CV("https://faktory.fun/pool/sbtc")),
    ],
  })

  // Register PEPE pool
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "register-pool",
    function_args: [
      contractPrincipalCV(
        "SP6SA6BTPNN5WDAWQ7GWJF1T5E2KWY01K9SZDBJQ",
        "pepe-faktory-pool"
      ),
      stringAsciiCV("PEPE-STX LP"),
      stringAsciiCV("PEPE-STX"),
      principalCV(
        "SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4kx15t9102"
      ),
      principalCV("SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9.token-wstx"),
      uintCV(150300),
      uintCV(30),
      someCV(stringUtf8CV("https://faktory.fun/pool/pepe")),
    ],
  })

  // Check all pools registered
  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, "(get-last-pool-id)")

  // ===== ERROR TESTS =====

  // TEST: Duplicate registration
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "register-pool",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "leo-faktory-pool"
      ),
      stringAsciiCV("LEO Duplicate"),
      stringAsciiCV("LEO-DUP"),
      principalCV(TOKEN_X),
      principalCV(TOKEN_Y),
      uintCV(150000),
      uintCV(30),
      noneCV(),
    ],
  })

  // TEST: Unauthorized registration
  .withSender(RANDOM_USER)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "register-pool",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "leo-faktory-pool"
      ),
      stringAsciiCV("Fake Pool"),
      stringAsciiCV("FAKE"),
      principalCV(TOKEN_X),
      principalCV(TOKEN_Y),
      uintCV(150100),
      uintCV(25),
      noneCV(),
    ],
  })

  // TEST: Empty name validation
  .withSender(DEPLOYER)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "register-pool",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "leo-faktory-pool"
      ),
      stringAsciiCV(""),
      stringAsciiCV("TEST"),
      principalCV(TOKEN_X),
      principalCV(TOKEN_Y),
      uintCV(150100),
      uintCV(25),
      noneCV(),
    ],
  })

  // TEST: Empty symbol validation
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "register-pool",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "leo-faktory-pool"
      ),
      stringAsciiCV("Test Pool"),
      stringAsciiCV(""),
      principalCV(TOKEN_X),
      principalCV(TOKEN_Y),
      uintCV(150100),
      uintCV(25),
      noneCV(),
    ],
  })

  // ===== EDIT POOL TESTS =====

  // TEST: Edit pool successfully
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "edit-pool",
    function_args: [
      uintCV(1),
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "leo-faktory-pool"
      ),
      stringAsciiCV("LEO-STX LP v2"),
      stringAsciiCV("LEO-STX-V2"),
      principalCV("SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9.token-wleo"),
      principalCV("SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9.token-wstx"),
      uintCV(150000),
      uintCV(35),
      someCV(stringUtf8CV("https://faktory.fun/pool/leo-v2")),
    ],
  })

  // TEST: Unauthorized edit
  .withSender(RANDOM_USER)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "edit-pool",
    function_args: [
      uintCV(1),
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "leo-faktory-pool"
      ),
      stringAsciiCV("Hacked"),
      stringAsciiCV("HACK"),
      principalCV(TOKEN_X),
      principalCV(TOKEN_Y),
      uintCV(150000),
      uintCV(100),
      noneCV(),
    ],
  })

  // TEST: Edit non-existent pool
  .withSender(DEPLOYER)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "edit-pool",
    function_args: [
      uintCV(999),
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "leo-faktory-pool"
      ),
      stringAsciiCV("Ghost Pool"),
      stringAsciiCV("GHOST"),
      principalCV(TOKEN_X),
      principalCV(TOKEN_Y),
      uintCV(150000),
      uintCV(30),
      noneCV(),
    ],
  })

  // TEST: Edit with empty name
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "edit-pool",
    function_args: [
      uintCV(1),
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "leo-faktory-pool"
      ),
      stringAsciiCV(""),
      stringAsciiCV("LEO-STX"),
      principalCV(TOKEN_X),
      principalCV(TOKEN_Y),
      uintCV(150000),
      uintCV(30),
      noneCV(),
    ],
  })

  // ===== GET-POOL TESTS =====

  // Get LEO pool with reserves
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "get-pool",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "leo-faktory-pool"
      ),
    ],
  })

  // Get B pool with reserves
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "get-pool",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "b-faktory-pool"
      ),
    ],
  })

  // ===== EXECUTE OPERATIONS - BUY AND SELL ON ALL 4 POOLS =====

  // === LEO POOL ===
  .withSender(SBTC_USER_1)
  // Buy LEO tokens
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "leo-faktory-pool"
      ),
      uintCV(1000000), // Buy with 1M sBTC
      someCV(OP_SWAP_A_TO_B),
    ],
  })
  // Sell LEO tokens back
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "leo-faktory-pool"
      ),
      uintCV(1000000000000), // Sell LEO tokens
      someCV(OP_SWAP_B_TO_A),
    ],
  })

  // === B POOL ===
  .withSender(SBTC_USER_2)
  // Buy B tokens
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "b-faktory-pool"
      ),
      uintCV(1000000), // Buy with 1M sBTC
      someCV(OP_SWAP_A_TO_B),
    ],
  })
  // Sell B tokens back
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "b-faktory-pool"
      ),
      uintCV(500000000000), // Sell B tokens
      someCV(OP_SWAP_B_TO_A),
    ],
  })

  // === sBTC POOL ===
  .withSender(SBTC_USER_3)
  // Buy FakFun tokens
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS",
        "sbtc-fakfun-amm-lp-v1"
      ),
      uintCV(1000000), // Buy with 1M sBTC
      someCV(OP_SWAP_A_TO_B),
    ],
  })
  // Sell FakFun tokens back
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS",
        "sbtc-fakfun-amm-lp-v1"
      ),
      uintCV(1000000000000), // Sell FakFun tokens
      someCV(OP_SWAP_B_TO_A),
    ],
  })

  // === PEPE POOL ===
  .withSender(SBTC_USER_1)
  // Buy PEPE tokens
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SP6SA6BTPNN5WDAWQ7GWJF1T5E2KWY01K9SZDBJQ",
        "pepe-faktory-pool"
      ),
      uintCV(1000000), // Buy with 1M sBTC
      someCV(OP_SWAP_A_TO_B),
    ],
  })
  // Sell PEPE tokens back
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SP6SA6BTPNN5WDAWQ7GWJF1T5E2KWY01K9SZDBJQ",
        "pepe-faktory-pool"
      ),
      uintCV(1000000000000), // Sell PEPE tokens
      someCV(OP_SWAP_B_TO_A),
    ],
  })

  // === BONUS: Test Add/Remove Liquidity on one pool ===
  .withSender(SBTC_USER_2)
  // Add liquidity to B pool (user already has B tokens from earlier buy)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "b-faktory-pool"
      ),
      uintCV(500000), // Amount of sBTC to add
      someCV(OP_ADD_LIQUIDITY),
    ],
  })
  // Remove liquidity from B pool
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "b-faktory-pool"
      ),
      uintCV(100000), // Amount of LP tokens to remove
      someCV(OP_REMOVE_LIQUIDITY),
    ],
  })

  // ===== ERROR TESTS FOR EXECUTE =====

  // TEST: Execute on unregistered pool (BOB pool exists but not registered)
  .withSender(SBTC_USER_1)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "bob-faktory-pool"
      ),
      uintCV(1000000),
      someCV(OP_SWAP_A_TO_B),
    ],
  })

  // TEST: Execute with default opcode (defaults to 0x00/buy)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "leo-faktory-pool"
      ),
      uintCV(100000),
      noneCV(),
    ],
  })

  // ===== LOOKUP TESTS =====

  .withSender(DEPLOYER)
  .addEvalCode(
    `${DEPLOYER}.faktory-pool-registry`,
    `(get-pool-by-contract '${LEO_POOL})`
  )
  .addEvalCode(
    `${DEPLOYER}.faktory-pool-registry`,
    `(get-pool-by-contract '${BOB_POOL})`
  )
  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, "(get-pool-by-id u1)")
  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, "(get-pool-by-id u999)")
  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, "(get-last-pool-id)")

  .run()
  .catch(console.error);

/*
Expected Results:

✅ Deploy registry
✅ Register 4 pools (LEO, B, sBTC, PEPE)
✅ Duplicate registration fails (ERR_POOL_ALREADY_EXISTS u1002)
✅ Unauthorized registration fails (ERR_NOT_AUTHORIZED u1001)
✅ Empty name fails (ERR_INVALID_POOL_DATA u1004)
✅ Empty symbol fails (ERR_INVALID_POOL_DATA u1004)
✅ Edit pool succeeds
✅ Unauthorized edit fails (ERR_NOT_AUTHORIZED u1001)
✅ Edit non-existent fails (ERR_POOL_NOT_FOUND u1003)
✅ Edit empty name fails (ERR_INVALID_POOL_DATA u1004)
✅ Get pool with reserves succeeds
✅ OP_SWAP_A_TO_B (Buy) succeeds
✅ OP_SWAP_B_TO_A (Sell) succeeds (user has tokens from buy)
✅ OP_ADD_LIQUIDITY succeeds
✅ OP_REMOVE_LIQUIDITY succeeds (user has LP tokens from add)
✅ Execute unregistered pool fails (ERR_POOL_NOT_FOUND u1003)
✅ Execute with default opcode succeeds (buy)
✅ Lookup tests verify pool data

Total: 4 pools registered, all operations demonstrated successfully!
*/

// --------------------------------
// Using block height 4097147 hash 0xbe297751fbf26a1b014cf5bedd56ebafe31b511a1899613e1bafcd670e72b3ab to run simulation.
// Simulation will be available at: https://stxer.xyz/simulations/mainnet/97f89460c6012aef760625aeef3a0925

// Using block height 4097299 hash 0xbcbe7e95a70e0f94e7ca6f3c388c555eb78fa198be63e12c11ff82f473ff45d8 to run simulation.
// Simulation will be available at: https://stxer.xyz/simulations/mainnet/762670e04f90a2095e982c51efd62b86

// https://stxer.xyz/simulations/mainnet/762670e04f90a2095e982c51efd62b86
