import fs from "node:fs";
import { uintCV, ClarityVersion } from "@stacks/transactions";
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

  .withSender(PEPE_USER)

  // ===== TEST ROUTE 1: PEPE -> sBTC -> STX -> PEPE =====
  .addContractCall({
    contract_id: `${DEPLOYER}.pepe-arbitrage-faktory`,
    function_name: "arb-sell-fak",
    function_args: [
      uintCV(TEN_MILLION_PEPE), // 10M PEPE (with 3 decimals)
      uintCV(1), // min-pepe-out = 1
    ],
  })

  // ===== TEST ROUTE 2: PEPE -> STX -> sBTC -> PEPE =====
  .addContractCall({
    contract_id: `${DEPLOYER}.pepe-arbitrage-faktory`,
    function_name: "arb-sell-velar",
    function_args: [
      uintCV(TEN_MILLION_PEPE), // 10M PEPE
      uintCV(1), // min-pepe-out = 1
    ],
  })

  .run()
  .catch(console.error);

/*
Expected Results:

✅ Deploy pepe-arbitrage-faktory contract

✅ TEST 1 - arb-sell-fak (PEPE -> sBTC -> STX -> PEPE):
   - Route: PEPE -> sBTC (Charisma) -> STX (Bitflow) -> PEPE (Velar)
   - Returns: { pepe-in, pepe-out, burnt-pepe }
   - Check the burnt-pepe amount to see profit

✅ TEST 2 - arb-sell-velar (PEPE -> STX -> sBTC -> PEPE):
   - Route: PEPE -> STX (Velar) -> sBTC (Bitflow) -> PEPE (Charisma)
   - Returns: { pepe-in, pepe-out, burnt-pepe }
   - Check the burnt-pepe amount to see profit

Compare both routes to see which is more profitable!

The arbitrage will:
1. Execute both routes with the same 10M PEPE input
2. Return profit breakdown for each
3. Show which direction has better rates

If either route is not profitable, it will revert with ERR-NO-PROFIT (u1001).
*/
