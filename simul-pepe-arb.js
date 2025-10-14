import fs from "node:fs";
import { uintCV, principalCV, ClarityVersion } from "@stacks/transactions";
import { SimulationBuilder } from "stxer";

// Define addresses
const DEPLOYER = "SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM";
const PEPE_USER = "SP3YM5YRTKHTWRC82K5DZJBY9XW0K4AX0P9PM5VSH"; // Has PEPE

// PEPE has 3 decimals, so 10 million = 10,000,000 * 1000 = 10,000,000,000
const TEN_MILLION_PEPE = 10000000000n; // 10M PEPE with 3 decimals

SimulationBuilder.new()
  .withSender(DEPLOYER)

  // ===== DEPLOY ARBITRAGE CONTRACT =====
  .addContractDeploy({
    contract_name: "pepe-arbitrage-faktory",
    source_code: fs.readFileSync(
      "./contracts/pepe-arbitrage-faktory.clar",
      "utf8"
    ),
    clarity_version: ClarityVersion.Clarity3,
  })

  // ===== TEST ARBITRAGE: PEPE -> sBTC -> STX -> PEPE =====
  .withSender(PEPE_USER)
  .addContractCall({
    contract_id: `${DEPLOYER}.pepe-arbitrage-faktory`,
    function_name: "arb-sell-fak",
    function_args: [
      uintCV(TEN_MILLION_PEPE), // 10M PEPE (with 3 decimals)
      uintCV(1), // min-pepe-out = 1 (just needs to complete, we'll check profit)
    ],
  })

  // ===== OPTIONAL: TEST REVERSE ROUTE =====
  // Uncomment if you want to also test the reverse arbitrage
  /*
  .addContractCall({
    contract_id: `${DEPLOYER}.pepe-arbitrage-faktory`,
    function_name: "arb-sell-velar",
    function_args: [
      uintCV(TEN_MILLION_PEPE), // 10M PEPE
      uintCV(1), // min-pepe-out
    ],
  })
  */

  .run()
  .catch(console.error);

/*
Expected Results:

✅ Deploy pepe-arbitrage-faktory contract
✅ Execute arb-sell-fak with 10M PEPE:
   - Route: PEPE -> sBTC (Charisma) -> STX (Bitflow) -> PEPE (Velar)
   - Returns: { pepe-in, pepe-out, profit }
   - Should either succeed with profit or fail with ERR-NO-PROFIT (u1001)

The arbitrage will:
1. Swap 10M PEPE → sBTC via Charisma Faktory pool
2. Swap sBTC → STX via Bitflow xyk pool  
3. Swap STX → PEPE via Velar (wrapping/unwrapping WSTX)
4. Check if pepe-out > pepe-in (profit check)
5. Check if pepe-out >= min-pepe-out (slippage check)

If profitable, returns the profit amount.
If not, reverts with ERR-NO-PROFIT.
*/
