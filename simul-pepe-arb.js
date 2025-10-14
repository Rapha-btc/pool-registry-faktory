import fs from "node:fs";
import { uintCV, ClarityVersion } from "@stacks/transactions";
import { SimulationBuilder } from "stxer";

// Define addresses
const DEPLOYER = "SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM";
const PEPE_USER = "SP3YM5YRTKHTWRC82K5DZJBY9XW0K4AX0P9PM5VSH"; // Has PEPE

// Test different amounts to find profitable size
const amounts = [
  100000000n, // 100K PEPE
  500000000n, // 500K PEPE
  1000000000n, // 1M PEPE
  5000000000n, // 5M PEPE
  10000000000n, // 10M PEPE
  12000000000n, // 12M PEPE
  50000000000n, // 50M PEPE
];

const builder = SimulationBuilder.new()
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

  .withSender(PEPE_USER);

// ===== SIMULATE ALL AMOUNTS FOR ALL 4 ROUTES =====
console.log("\n=== SIMULATING ARBITRAGE OPPORTUNITIES (ALL 4 ROUTES) ===\n");

for (const amount of amounts) {
  builder
    // Route 1: PEPE -> sBTC (Faktory) -> STX (Bitflow) -> PEPE (Velar)
    .addEvalCode(
      `${DEPLOYER}.pepe-arbitrage-faktory`,
      `(check-arb-fak u${amount})`
    )
    // Route 2: PEPE -> STX (Velar) -> sBTC (Bitflow) -> PEPE (Faktory)
    .addEvalCode(
      `${DEPLOYER}.pepe-arbitrage-faktory`,
      `(check-arb-velar u${amount})`
    )
    // Route 3: PEPE -> sBTC (Faktory) -> STX (Velar u70) -> PEPE (Velar)
    .addEvalCode(
      `${DEPLOYER}.pepe-arbitrage-faktory`,
      `(check-arb-fak-velar u${amount})`
    )
    // Route 4: PEPE -> STX (Velar) -> sBTC (Velar u70) -> PEPE (Faktory)
    .addEvalCode(
      `${DEPLOYER}.pepe-arbitrage-faktory`,
      `(check-arb-velar-velar u${amount})`
    );
}

// ===== EXECUTE ACTUAL ARBITRAGE WITH 12M PEPE ON ALL 4 ROUTES =====
const EXECUTION_AMOUNT = 12000000000n;

builder
  // ===== TEST ROUTE 1: PEPE -> sBTC (Faktory) -> STX (Bitflow) -> PEPE =====
  .addContractCall({
    contract_id: `${DEPLOYER}.pepe-arbitrage-faktory`,
    function_name: "arb-sell-fak",
    function_args: [
      uintCV(EXECUTION_AMOUNT),
      uintCV(1), // min-pepe-out = 1
    ],
  })

  // ===== TEST ROUTE 2: PEPE -> STX (Velar) -> sBTC (Bitflow) -> PEPE =====
  .addContractCall({
    contract_id: `${DEPLOYER}.pepe-arbitrage-faktory`,
    function_name: "arb-sell-velar",
    function_args: [
      uintCV(EXECUTION_AMOUNT),
      uintCV(1), // min-pepe-out = 1
    ],
  })

  // ===== TEST ROUTE 3: PEPE -> sBTC (Faktory) -> STX (Velar u70) -> PEPE =====
  .addContractCall({
    contract_id: `${DEPLOYER}.pepe-arbitrage-faktory`,
    function_name: "arb-sell-fak-velar",
    function_args: [
      uintCV(EXECUTION_AMOUNT),
      uintCV(1), // min-pepe-out = 1
    ],
  })

  // ===== TEST ROUTE 4: PEPE -> STX (Velar) -> sBTC (Velar u70) -> PEPE =====
  .addContractCall({
    contract_id: `${DEPLOYER}.pepe-arbitrage-faktory`,
    function_name: "arb-sell-velar-velar",
    function_args: [
      uintCV(EXECUTION_AMOUNT),
      uintCV(1), // min-pepe-out = 1
    ],
  })

  .run()
  .catch(console.error);

/*
Expected Results:

✅ Deploy pepe-arbitrage-faktory contract

✅ SIMULATIONS (for each amount, 4 routes each):
   
   Route 1 - check-arb-fak: 
     { pepe-in, sbtc-out, stx-out, pepe-out, profit, profitable }
     PEPE -> sBTC (Faktory) -> STX (Bitflow) -> PEPE (Velar)
   
   Route 2 - check-arb-velar: 
     { pepe-in, stx-out, sbtc-out, pepe-out, profit, profitable }
     PEPE -> STX (Velar) -> sBTC (Bitflow) -> PEPE (Faktory)
   
   Route 3 - check-arb-fak-velar: 
     { pepe-in, sbtc-out, stx-out, pepe-out, profit, profitable }
     PEPE -> sBTC (Faktory) -> STX (Velar u70) -> PEPE (Velar)
   
   Route 4 - check-arb-velar-velar: 
     { pepe-in, stx-out, sbtc-out, pepe-out, profit, profitable }
     PEPE -> STX (Velar) -> sBTC (Velar u70) -> PEPE (Faktory)
   
   Look for:
   - Which amounts show profitable: true for each route
   - Which route has the highest profit at each amount
   - Compare Bitflow routes vs Velar u70 routes
   - Price impact as amount increases

✅ ACTUAL EXECUTION (12M PEPE on all 4 routes):
   
   TEST 1 - arb-sell-fak (Faktory -> Bitflow -> Velar)
     Returns: { pepe-in, pepe-out, burnt-pepe }
   
   TEST 2 - arb-sell-velar (Velar -> Bitflow -> Faktory)
     Returns: { pepe-in, pepe-out, burnt-pepe }
   
   TEST 3 - arb-sell-fak-velar (Faktory -> Velar u70 -> Velar)
     Returns: { pepe-in, pepe-out, burnt-pepe }
   
   TEST 4 - arb-sell-velar-velar (Velar -> Velar u70 -> Faktory)
     Returns: { pepe-in, pepe-out, burnt-pepe }

Analysis:
1. Check simulations to find the sweet spot amount for each route
2. Compare profit between all 4 routes at each amount
3. Identify which route is most profitable
4. See if Velar u70 routes capture more PEPE due to price inefficiency
5. Verify actual execution matches simulation
6. If all fail with ERR-NO-PROFIT, check smaller amounts

Key Questions Answered:
- Does Velar u70's shallow liquidity create exploitable price gaps?
- Do lower fees on Velar u70 (0.3% vs 0.5% Bitflow) offset slippage?
- Which route burns the most PEPE?

The simulation results will show you exactly which route and amount
maximizes PEPE capture and burn! 🔥
*/
