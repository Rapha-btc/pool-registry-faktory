/*
## Pool Registry + Auto-Registration with Real Tokens

Strategy:
1. Use sBTC holder as deployer
2. Deploy registry
3. Buy LEO from existing mainnet pool (to get LEO tokens)
4. Deploy new pool with liquidity (auto-registers)
5. Execute operations through registry
*/

import fs from "node:fs";
import {
  uintCV,
  principalCV,
  someCV,
  bufferCV,
  ClarityVersion,
  contractPrincipalCV,
} from "@stacks/transactions";
import { SimulationBuilder } from "stxer";

// Use sBTC holder as deployer
const DEPLOYER = "SP2QGMXH21KFDX99PWNB7Z7WNQ92TWFAECEEK10GE"; // Has sBTC ✅
const USER_WITH_SBTC = "SP1DZARHA1GVEWVCDF1J9N044A69Q6VT7KMDPQ5N9"; // Has sBTC ✅

// Existing mainnet pool to buy LEO from
const MAINNET_LEO_POOL =
  "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.leo-faktory-pool";

// Opcodes
const OP_SWAP_A_TO_B = bufferCV(Buffer.from([0x00]));
const OP_SWAP_B_TO_A = bufferCV(Buffer.from([0x01]));
const OP_ADD_LIQUIDITY = bufferCV(Buffer.from([0x02]));

SimulationBuilder.new()
  .withSender(DEPLOYER)

  // ===== STEP 1: DEPLOY REGISTRY =====
  .addContractDeploy({
    contract_name: "faktory-core-v1",
    source_code: fs.readFileSync("./contracts/faktory-core-v1.clar", "utf8"),
    clarity_version: ClarityVersion.Clarity3,
  })

  .addEvalCode(`${DEPLOYER}.faktory-core-v1`, "(get-last-pool-id)")

  // ===== STEP 2: BUY LEO FROM MAINNET POOL =====
  // Deployer buys LEO so they have both sBTC and LEO for new pool
  .addContractCall({
    contract_id: MAINNET_LEO_POOL,
    function_name: "swap-a-to-b",
    function_args: [
      uintCV(10000000), // 10 sBTC to buy LEO
      uintCV(0), // min-y-out
    ],
  })

  // Check deployer now has LEO
  .addContractCall({
    contract_id: "SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token",
    function_name: "get-balance",
    function_args: [principalCV(DEPLOYER)],
  })

  // ===== STEP 3: DEPLOY POOL WITH LIQUIDITY (AUTO-REGISTERS) =====
  .addContractDeploy({
    contract_name: "leo-faktory-pool-deployed",
    source_code: fs.readFileSync(
      "./contracts/leo-faktory-pool-deployed.clar",
      "utf8"
    ),
    clarity_version: ClarityVersion.Clarity3,
  })

  // ===== STEP 4: VERIFY AUTO-REGISTRATION =====
  .addEvalCode(`${DEPLOYER}.faktory-core-v1`, "(get-last-pool-id)")

  .addEvalCode(`${DEPLOYER}.faktory-core-v1`, "(get-pool-by-id u1)")

  .addEvalCode(
    `${DEPLOYER}.faktory-core-v1`,
    `(get-pool-by-contract '${DEPLOYER}.leo-faktory-pool-deployed)`
  )

  // Get full pool info with reserves via registry
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-core-v1`,
    function_name: "get-pool",
    function_args: [
      contractPrincipalCV(DEPLOYER.split(".")[0], "leo-faktory-pool-deployed"),
    ],
  })

  // ===== STEP 5: OPERATIONS THROUGH REGISTRY =====
  .withSender(USER_WITH_SBTC)

  // Buy LEO from new pool
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-core-v1`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(DEPLOYER.split(".")[0], "leo-faktory-pool-deployed"),
      uintCV(1000000), // 1 sBTC
      someCV(OP_SWAP_A_TO_B),
    ],
  })

  // Sell LEO back
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-core-v1`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(DEPLOYER.split(".")[0], "leo-faktory-pool-deployed"),
      uintCV(500000000000), // 500k LEO
      someCV(OP_SWAP_B_TO_A),
    ],
  })

  // Add liquidity
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-core-v1`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(DEPLOYER.split(".")[0], "leo-faktory-pool-deployed"),
      uintCV(500000), // 0.5 sBTC worth
      someCV(OP_ADD_LIQUIDITY),
    ],
  })

  // ===== FINAL VERIFICATION =====
  .addEvalCode(`${DEPLOYER}.faktory-core-v1`, "(get-pool-by-id u1)")

  .run()
  .catch(console.error);

/*
Expected Flow:
✅ Deploy registry (pool counter = 0)
✅ Buy LEO from mainnet pool (deployer now has LEO + sBTC)
✅ Deploy new pool with liquidity uncommented (auto-registers)
✅ Pool counter = 1
✅ Registry has pool metadata
✅ Execute operations through registry with full event tracking
✅ Registry events include pool metadata + reserves
*/

// https://stxer.xyz/simulations/mainnet/35a8aa5cd9afd37bc74df0d0c51e6bfb
// all green

// https://stxer.xyz/simulations/mainnet/c65395f572586dfd098921bfa7b396b3
// showing beautiful logs for indexers
