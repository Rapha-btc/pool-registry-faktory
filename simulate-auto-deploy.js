/*
## Pool Registry + Auto-Registration Test

This simulation tests:
1. Deploy faktory-core-v1 registry
2. Deploy leo-faktory-pool which auto-registers itself on deployment
3. Verify registration worked
4. Execute operations through the registry
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

// Define addresses - using address that has sBTC and LEO tokens
const DEPLOYER = "SP2QGMXH21KFDX99PWNB7Z7WNQ92TWFAECEEK10GE"; // Has sBTC ✅
const USER_1 = "SP1DZARHA1GVEWVCDF1J9N044A69Q6VT7KMDPQ5N9"; // Has sBTC ✅

// Token addresses
const SBTC_TOKEN = "SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token";
const LEO_TOKEN = "SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token";

// Opcodes
const OP_SWAP_A_TO_B = bufferCV(Buffer.from([0x00]));
const OP_SWAP_B_TO_A = bufferCV(Buffer.from([0x01]));
const OP_ADD_LIQUIDITY = bufferCV(Buffer.from([0x02]));
const OP_REMOVE_LIQUIDITY = bufferCV(Buffer.from([0x03]));

SimulationBuilder.new()
  .withSender(DEPLOYER)

  // ===== STEP 1: DEPLOY REGISTRY =====
  .addContractDeploy({
    contract_name: "faktory-core-v1",
    source_code: fs.readFileSync("./contracts/faktory-core-v1.clar", "utf8"),
    clarity_version: ClarityVersion.Clarity3,
  })

  // Verify registry deployed
  .addEvalCode(`${DEPLOYER}.faktory-core-v1`, "(get-last-pool-id)")

  // ===== STEP 2: DEPLOY POOL (AUTO-REGISTERS ITSELF) =====
  .addContractDeploy({
    contract_name: "leo-faktory-pool-deployed",
    source_code: fs.readFileSync(
      "./contracts/leo-faktory-pool-deployed.clar",
      "utf8"
    ),
    clarity_version: ClarityVersion.Clarity3,
  })

  // ===== STEP 3: VERIFY AUTO-REGISTRATION =====

  // Check pool counter increased
  .addEvalCode(`${DEPLOYER}.faktory-core-v1`, "(get-last-pool-id)")

  // Look up pool by ID
  .addEvalCode(`${DEPLOYER}.faktory-core-v1`, "(get-pool-by-id u1)")

  // Look up pool by contract address
  .addEvalCode(
    `${DEPLOYER}.faktory-core-v1`,
    `(get-pool-by-contract '${DEPLOYER}.leo-faktory-pool-deployed)`
  )

  // Get full pool info with reserves
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-core-v1`,
    function_name: "get-pool",
    function_args: [
      contractPrincipalCV(DEPLOYER.split(".")[0], "leo-faktory-pool-deployed"),
    ],
  })

  // ===== STEP 4: EXECUTE OPERATIONS THROUGH REGISTRY =====

  .withSender(USER_1)

  // Buy LEO with sBTC (Swap A to B)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-core-v1`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(DEPLOYER.split(".")[0], "leo-faktory-pool-deployed"),
      uintCV(1000000), // 1 sBTC
      someCV(OP_SWAP_A_TO_B),
    ],
  })

  // Sell LEO for sBTC (Swap B to A)
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

  // Remove liquidity
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-core-v1`,
    function_name: "execute",
    function_args: [
      contractPrincipalCV(DEPLOYER.split(".")[0], "leo-faktory-pool-deployed"),
      uintCV(100000), // 0.1 LP tokens
      someCV(OP_REMOVE_LIQUIDITY),
    ],
  })

  // ===== STEP 5: VERIFY EVENTS =====

  // Check pool info again to see updated reserves
  .withSender(DEPLOYER)
  .addContractCall({
    contract_id: `${DEPLOYER}.faktory-core-v1`,
    function_name: "get-pool",
    function_args: [
      contractPrincipalCV(DEPLOYER.split(".")[0], "leo-faktory-pool-deployed"),
    ],
  })

  .run()
  .catch(console.error);

/*
Expected Results:

✅ Deploy faktory-core-v1 registry
✅ last-pool-id = 0 initially
✅ Deploy leo-faktory-pool-deployed
   - Pool initialization runs
   - Adds initial liquidity (1.863157 sBTC + LEO)
   - Transfers additional LEO tokens
   - AUTO-REGISTERS itself with registry
   - Emits initialize-pool event
✅ last-pool-id = 1 after deployment
✅ get-pool-by-id u1 returns pool info
✅ get-pool-by-contract returns same pool info
✅ get-pool returns full info with reserves
✅ Execute swap A→B through registry (emits "buy" event)
✅ Execute swap B→A through registry (emits "sell" event)  
✅ Execute add-liquidity through registry
✅ Execute remove-liquidity through registry
✅ Final get-pool shows updated reserves

Key Benefits:
- Pool registers itself on deployment (no separate step!)
- All events flow through registry for unified tracking
- Registry emits comprehensive events with pool metadata
- Reserves are always up-to-date via quote calls
*/
