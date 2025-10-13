/*
## Faktory Account + Pre Registry Simulation

Tests the full stack:
1. Deploy account infrastructure (traits, registry, account v1)
2. Deploy pre-faktory contract
3. Deploy pool registry
4. Register dex/pre pair
5. Test buy/refund seats with agent accounts
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
const SBTC_USER = "SP2QGMXH21KFDX99PWNB7Z7WNQ92TWFAECEEK10GE"; // Has sBTC & seats
const RANDOM_USER = "SP1K1A1PMGW2ZJCNF46NWZWHG8TS1D23EGH1KNK60";

// Token addresses
const SBTC_TOKEN = "SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token";
const FAKE_TOKEN = "SP2Z94F6QX847PMXTPJJ2ZCCN79JZDW3PJ4E6ZABY.fake-faktory";

// External dex contract (already deployed)
const FAKE_DEX = "SP2Z94F6QX847PMXTPJJ2ZCCN79JZDW3PJ4E6ZABY.fake-faktory-dex";

// Opcodes
const OP_SWAP_A_TO_B = bufferCV(Buffer.from([0x00]));
const OP_SWAP_B_TO_A = bufferCV(Buffer.from([0x01]));
const OP_ADD_LIQUIDITY = bufferCV(Buffer.from([0x02]));
const OP_REMOVE_LIQUIDITY = bufferCV(Buffer.from([0x03]));

SimulationBuilder.new()
  .withSender(DEPLOYER)

  // ===== DEPLOY ACCOUNT INFRASTRUCTURE =====

  // 1. Deploy traits
  .addContractDeploy({
    contract_name: "faktory-account-traits",
    source_code: fs.readFileSync(
      "./contracts/faktory-account-traits.clar",
      "utf8"
    ),
    clarity_version: ClarityVersion.Clarity3,
  })

  // 2. Deploy registry
  .addContractDeploy({
    contract_name: "faktory-account-registry",
    source_code: fs.readFileSync(
      "./contracts/faktory-account-registry.clar",
      "utf8"
    ),
    clarity_version: ClarityVersion.Clarity3,
  })

  // 3. Deploy account v1
  .addContractDeploy({
    contract_name: "faktory-account-v1",
    source_code: fs.readFileSync("./contracts/faktory-account-v1.clar", "utf8"),
    clarity_version: ClarityVersion.Clarity3,
  })

  // 4. Deploy pre-faktory
  .addContractDeploy({
    contract_name: "fakememe-pre-faktory",
    source_code: fs.readFileSync(
      "./contracts/fakememe-pre-faktory.clar",
      "utf8"
    ),
    clarity_version: ClarityVersion.Clarity3,
  })

  // 5. Deploy pool registry
  .addContractDeploy({
    contract_name: "faktory-pool-registry",
    source_code: fs.readFileSync(
      "./contracts/faktory-pool-registry.clar",
      "utf8"
    ),
    clarity_version: ClarityVersion.Clarity3,
  })

  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, "(get-last-dex-id)")

  // ===== REGISTER DEX/PRE PAIR =====

  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "register-dex",
    function_args: [
      principalCV(FAKE_DEX),
      principalCV(`${DEPLOYER}.fakememe-pre-faktory`),
      principalCV(SBTC_TOKEN),
      principalCV(FAKE_TOKEN),
      uintCV(21000000),
      uintCV(100000000000000000n), // BigInt!
      someCV(uintCV(69000)),
      someCV(uintCV(1000000000000000n)), // BigInt!
      uintCV(876543),
    ],
  })

  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, "(get-last-dex-id)")
  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, `(get-dex-by-id u1)`)
  .addEvalCode(
    `${DEPLOYER}.faktory-pool-registry`,
    `(get-pre-by-contract '${DEPLOYER}.fakememe-pre-faktory)`
  )

  // ===== BUY SEATS - Without agent account (owner = none) =====

  .withSender(SBTC_USER)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "prelaunch",
    function_args: [
      contractPrincipalCV(DEPLOYER, "fakememe-pre-faktory"),
      uintCV(3), // buy 3 seats
      noneCV(), // owner defaults to tx-sender
      someCV(OP_ADD_LIQUIDITY),
    ],
  })

  // ===== BUY SEATS - With agent account (owner = faktory-account-v1) =====

  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "prelaunch",
    function_args: [
      contractPrincipalCV(DEPLOYER, "fakememe-pre-faktory"),
      uintCV(5), // buy 5 seats
      someCV(contractPrincipalCV(DEPLOYER, "faktory-account-v1")), // 🔑 agent account as owner
      someCV(OP_ADD_LIQUIDITY),
    ],
  })

  // ===== REFUND SEATS - Without agent account =====

  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "prelaunch",
    function_args: [
      contractPrincipalCV(DEPLOYER, "fakememe-pre-faktory"),
      uintCV(0), // seat-count ignored for refund
      noneCV(), // refund for tx-sender
      someCV(OP_REMOVE_LIQUIDITY),
    ],
  })

  // ===== REFUND SEATS - With agent account =====

  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "prelaunch",
    function_args: [
      contractPrincipalCV(DEPLOYER, "fakememe-pre-faktory"),
      uintCV(0), // seat-count ignored
      someCV(contractPrincipalCV(DEPLOYER, "faktory-account-v1")), // 🔑 agent account as owner
      someCV(OP_REMOVE_LIQUIDITY),
    ],
  })

  // ===== ERROR TESTS =====

  // Unauthorized registration
  .withSender(RANDOM_USER)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "register-dex",
    function_args: [
      principalCV(`${RANDOM_USER}.fake-dex`),
      principalCV(`${RANDOM_USER}.fake-pre`),
      principalCV(SBTC_TOKEN),
      principalCV(FAKE_TOKEN),
      uintCV(1000000),
      uintCV(1000000000n),
      noneCV(),
      noneCV(),
      uintCV(100000),
    ],
  })

  // Execute on unregistered pre
  .withSender(SBTC_USER)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "prelaunch",
    function_args: [
      contractPrincipalCV(RANDOM_USER, "unregistered-pre"),
      uintCV(1),
      noneCV(),
      someCV(OP_ADD_LIQUIDITY),
    ],
  })

  // Invalid operation for prelaunch
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-pool-registry`,
    function_name: "prelaunch",
    function_args: [
      contractPrincipalCV(DEPLOYER, "fakememe-pre-faktory"),
      uintCV(1),
      noneCV(),
      someCV(OP_SWAP_A_TO_B), // invalid for prelaunch
    ],
  })

  // ===== VERIFY REGISTRY DATA =====
  .withSender(DEPLOYER)
  .addEvalCode(
    `${DEPLOYER}.faktory-pool-registry`,
    `(get-dex-by-contract '${FAKE_DEX})`
  )
  .addEvalCode(
    `${DEPLOYER}.faktory-pool-registry`,
    `(get-pre-by-contract '${DEPLOYER}.fakememe-pre-faktory)`
  )
  .addEvalCode(`${DEPLOYER}.faktory-pool-registry`, "(get-last-dex-id)")

  .run()
  .catch(console.error);

/*
Expected Results:

✅ Deploy all 5 contracts in order
✅ Register dex/pre pair (Fakememe)
✅ Buy 3 seats without agent account (owner = none)
✅ Buy 5 seats WITH agent account (owner = faktory-account-v1)
✅ Refund seats without agent account
✅ Refund seats WITH agent account
✅ Unauthorized registration fails (ERR_NOT_AUTHORIZED u1001)
✅ Execute unregistered pre fails (ERR_POOL_NOT_FOUND u1003)
✅ Invalid opcode fails (ERR_INVALID_OPERATION u1006)
✅ Verify registry lookups work correctly

Key test: Using someCV(contractPrincipalCV(DEPLOYER, "faktory-account-v1"))
as the owner parameter to test agent account integration! 🎯
*/

// https://stxer.xyz/simulations/mainnet/dd322908388243ba841ee1ced136bdcc
