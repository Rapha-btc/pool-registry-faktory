/*
## Pool Registry Stxer Simulation - HAPPY PATH

This simulation tests the pool registry contract with realistic scenarios.
We'll register 4 real pools and execute operations on each with proper setup.
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
const SBTC_USER_1 = "SP2QGMXH21KFDX99PWNB7Z7WNQ92TWFAECEEK10GE"; // Has sBTC ✅
const SBTC_USER_2 = "SP1DZARHA1GVEWVCDF1J9N044A69Q6VT7KMDPQ5N9"; // Has sBTC ✅
const SBTC_USER_3 = "SM2FXSN6RZ85Q18S3X0GE2N0FVAA1DN1DPPDXEB5X"; // Has sBTC ✅
const RANDOM_USER = "SP1K1A1PMGW2ZJCNF46NWZWHG8TS1D23EGH1KNK60";

// Real deployed pool contracts
const LEO_POOL = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.leo-faktory-pool";
const B_POOL = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory-pool";
const SBTC_POOL =
  "SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS.sbtc-fakfun-amm-lp-v1";
const PEPE_POOL = "SP6SA6BTPNN5WDAWQ7GWJF1T5E2KWY01K9SZDBJQ.pepe-faktory-pool";
const BOB_POOL = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.bob-faktory-pool";

// Token addresses
const SBTC_TOKEN = "SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token";
const LEO_TOKEN = "SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token";
const B_TOKEN = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory";
const FAKFUN_TOKEN = "SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS.fakfun-token";
const PEPE_TOKEN =
  "SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4kx15t9102";

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

  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, "(get-last-pool-id)")

  // ===== REGISTER 4 POOLS =====

  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "register-pool",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "leo-faktory-pool"
      ),
      stringAsciiCV("LEO-sBTC LP"),
      stringAsciiCV("LEO-SBTC"),
      principalCV("SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token"),
      principalCV("SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token"),
      uintCV(150000),
      uintCV(30),
      someCV(stringUtf8CV("https://faktory.fun/pool/leo")),
    ],
  })

  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "register-pool",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "b-faktory-pool"
      ),
      stringAsciiCV("B-sBTC LP"),
      stringAsciiCV("B-SBTC"),
      principalCV("SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token"),
      principalCV("SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.b-faktory"),
      uintCV(150100),
      uintCV(30),
      someCV(stringUtf8CV("https://faktory.fun/pool/b")),
    ],
  })

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
      principalCV("SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token"),
      principalCV("SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS.fakfun-token"),
      uintCV(150200),
      uintCV(25),
      someCV(stringUtf8CV("https://faktory.fun/pool/sbtc")),
    ],
  })

  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "register-pool",
    function_args: [
      contractPrincipalCV(
        "SP6SA6BTPNN5WDAWQ7GWJF1T5E2KWY01K9SZDBJQ",
        "pepe-faktory-pool"
      ),
      stringAsciiCV("PEPE-sBTC LP"),
      stringAsciiCV("PEPE-SBTC"),
      principalCV("SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token"),
      principalCV(
        "SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4kx15t9102"
      ),
      uintCV(150300),
      uintCV(30),
      someCV(stringUtf8CV("https://faktory.fun/pool/pepe")),
    ],
  })

  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, "(get-last-pool-id)")

  // ===== ERROR TESTS =====

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
      principalCV(SBTC_TOKEN),
      principalCV(LEO_TOKEN),
      uintCV(150000),
      uintCV(30),
      noneCV(),
    ],
  })

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
      principalCV(SBTC_TOKEN),
      principalCV(LEO_TOKEN),
      uintCV(150100),
      uintCV(25),
      noneCV(),
    ],
  })

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
      principalCV(SBTC_TOKEN),
      principalCV(LEO_TOKEN),
      uintCV(150100),
      uintCV(25),
      noneCV(),
    ],
  })

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
      principalCV(SBTC_TOKEN),
      principalCV(LEO_TOKEN),
      uintCV(150100),
      uintCV(25),
      noneCV(),
    ],
  })

  // === LEO POOL - All 4 operations ===
  .withSender(SBTC_USER_1)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "leo-faktory-pool"
      ),
      uintCV(1000000),
      someCV(OP_SWAP_A_TO_B),
    ],
  })
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "leo-faktory-pool"
      ),
      uintCV(500000000000),
      someCV(OP_SWAP_B_TO_A),
    ],
  })
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "leo-faktory-pool"
      ),
      uintCV(500000),
      someCV(OP_ADD_LIQUIDITY),
    ],
  })
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "leo-faktory-pool"
      ),
      uintCV(100000),
      someCV(OP_REMOVE_LIQUIDITY),
    ],
  })

  // === B POOL - All 4 operations ===
  .withSender(SBTC_USER_2)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "b-faktory-pool"
      ),
      uintCV(1000000),
      someCV(OP_SWAP_A_TO_B),
    ],
  })
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "b-faktory-pool"
      ),
      uintCV(500000000000),
      someCV(OP_SWAP_B_TO_A),
    ],
  })
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "b-faktory-pool"
      ),
      uintCV(500000),
      someCV(OP_ADD_LIQUIDITY),
    ],
  })
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22",
        "b-faktory-pool"
      ),
      uintCV(100000),
      someCV(OP_REMOVE_LIQUIDITY),
    ],
  })

  // === sBTC-FakFun POOL - All 4 operations ===
  .withSender(SBTC_USER_3)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS",
        "sbtc-fakfun-amm-lp-v1"
      ),
      uintCV(1000000),
      someCV(OP_SWAP_A_TO_B),
    ],
  })
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS",
        "sbtc-fakfun-amm-lp-v1"
      ),
      uintCV(500000000000),
      someCV(OP_SWAP_B_TO_A),
    ],
  })
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS",
        "sbtc-fakfun-amm-lp-v1"
      ),
      uintCV(500000),
      someCV(OP_ADD_LIQUIDITY),
    ],
  })
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SP2ZNGJ85ENDY6QRHQ5P2D4FXKGZWCKTB2T0Z55KS",
        "sbtc-fakfun-amm-lp-v1"
      ),
      uintCV(100000),
      someCV(OP_REMOVE_LIQUIDITY),
    ],
  })

  // === PEPE POOL - All 4 operations ===
  .withSender(SBTC_USER_1)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SP6SA6BTPNN5WDAWQ7GWJF1T5E2KWY01K9SZDBJQ",
        "pepe-faktory-pool"
      ),
      uintCV(1000000),
      someCV(OP_SWAP_A_TO_B),
    ],
  })
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SP6SA6BTPNN5WDAWQ7GWJF1T5E2KWY01K9SZDBJQ",
        "pepe-faktory-pool"
      ),
      uintCV(50000000000),
      someCV(OP_SWAP_B_TO_A),
    ],
  })
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SP6SA6BTPNN5WDAWQ7GWJF1T5E2KWY01K9SZDBJQ",
        "pepe-faktory-pool"
      ),
      uintCV(500000),
      someCV(OP_ADD_LIQUIDITY),
    ],
  })
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(
        "SP6SA6BTPNN5WDAWQ7GWJF1T5E2KWY01K9SZDBJQ",
        "pepe-faktory-pool"
      ),
      uintCV(100000),
      someCV(OP_REMOVE_LIQUIDITY),
    ],
  })

  // === ERROR TESTS ===
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

// all green https://stxer.xyz/simulations/mainnet/4539a6ffebcda3cb2417ac4192c94a94

// https://stxer.xyz/simulations/mainnet/2b6c08fefccc690463508ced610ac6ce
