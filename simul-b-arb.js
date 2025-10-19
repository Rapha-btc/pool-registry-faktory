import fs from "node:fs";
import { uintCV, ClarityVersion } from "@stacks/transactions";
import { SimulationBuilder } from "stxer";

// Define addresses
const DEPLOYER = "SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM";
const B_HOLDER = "SPWK34YZPVW724K9C8NRZA6VT4YDA2PB5SSD1VYF"; // User with B Blocks tokens

// Test different amounts to find profitable size
const amounts = [
  //  B Block (8 decimals)
  5000000000000n, // 100k B Blocks
  10000000000000n, // 100k B Blocks
  50000000000000n, // 500k B Blocks
  100000000000000n, // 1M B Blocks
  500000000000000n, // 5M B Blocks
  120000000000000n, // 1.2M B Blocks
];

const builder = SimulationBuilder.new()
  .withSender(DEPLOYER)

  // ===== DEPLOY ARBITRAGE CONTRACT =====
  .addContractDeploy({
    contract_name: "b-arbitrage-faktory",
    source_code: fs.readFileSync(
      "./contracts/b-arbitrage-faktory.clar",
      "utf8"
    ),
    clarity_version: ClarityVersion.Clarity3,
  })

  .withSender(B_HOLDER);

// ===== SIMULATE ALL AMOUNTS FOR ALL 4 ROUTES =====
console.log("\n=== SIMULATING ARBITRAGE OPPORTUNITIES (ALL 4 ROUTES) ===\n");

for (const amount of amounts) {
  builder
    // Route 1: B -> sBTC (Faktory) -> STX (Bitflow) -> B (Alex)
    .addEvalCode(
      `${DEPLOYER}.b-arbitrage-faktory`,
      `(check-fak-bit-alex u${amount})`
    )
    // Route 2: B -> STX (Alex) -> sBTC (Bitflow) -> B (Faktory)
    .addEvalCode(
      `${DEPLOYER}.b-arbitrage-faktory`,
      `(check-alex-bit-fak u${amount})`
    )
    // Route 3: B -> sBTC (Faktory) -> STX (Velar u70) -> B (Alex)
    .addEvalCode(
      `${DEPLOYER}.b-arbitrage-faktory`,
      `(check-fak-vel-alex u${amount})`
    )
    // Route 4: B -> STX (Alex) -> sBTC (Velar u70) -> B (Faktory)
    .addEvalCode(
      `${DEPLOYER}.b-arbitrage-faktory`,
      `(check-alex-vel-fak u${amount})`
    );
}

// ===== EXECUTE ACTUAL ARBITRAGE WITH PROFITABLE AMOUNT ON ALL 4 ROUTES =====
const EXECUTION_AMOUNT = 10000000000000n; // 100K B Blocks - adjust based on simulation results

builder
  // ===== TEST ROUTE 1: B -> sBTC (Faktory) -> STX (Bitflow) -> B (Alex) =====
  .addContractCall({
    contract_id: `${DEPLOYER}.b-arbitrage-faktory`,
    function_name: "arb-fak-bit-alex",
    function_args: [
      uintCV(EXECUTION_AMOUNT),
      uintCV(1), // min-token-out = 1
    ],
  })

  // ===== TEST ROUTE 2: B -> STX (Alex) -> sBTC (Bitflow) -> B (Faktory) =====
  .addContractCall({
    contract_id: `${DEPLOYER}.b-arbitrage-faktory`,
    function_name: "arb-alex-bit-fak",
    function_args: [
      uintCV(EXECUTION_AMOUNT),
      uintCV(1), // min-token-out = 1
    ],
  })

  // ===== TEST ROUTE 3: B -> sBTC (Faktory) -> STX (Velar u70) -> B (Alex) =====
  .addContractCall({
    contract_id: `${DEPLOYER}.b-arbitrage-faktory`,
    function_name: "arb-fak-vel-alex",
    function_args: [
      uintCV(EXECUTION_AMOUNT),
      uintCV(1), // min-token-out = 1
    ],
  })

  // ===== TEST ROUTE 4: B -> STX (Alex) -> sBTC (Velar u70) -> B (Faktory) =====
  .addContractCall({
    contract_id: `${DEPLOYER}.b-arbitrage-faktory`,
    function_name: "arb-alex-vel-fak",
    function_args: [
      uintCV(EXECUTION_AMOUNT),
      uintCV(1), // min-token-out = 1
    ],
  })

  .run()
  .catch(console.error);

/*
Expected Results:

✅ Deploy b-arbitrage-faktory contract

✅ SIMULATIONS (for each amount, 4 routes each):
   
   Route 1 - check-fak-bit-alex: 
     { token-in, sbtc-out, stx-out, token-out, profit, profitable }
     B -> sBTC (Faktory) -> STX (Bitflow) -> B (Alex)
   
   Route 2 - check-alex-bit-fak: 
     { token-in, stx-out, sbtc-out, token-out, profit, profitable }
     B -> STX (Alex) -> sBTC (Bitflow) -> B (Faktory)
   
   Route 3 - check-fak-vel-alex: 
     { token-in, sbtc-out, stx-out, token-out, profit, profitable }
     B -> sBTC (Faktory) -> STX (Velar u70) -> B (Alex)
   
   Route 4 - check-alex-vel-fak: 
     { token-in, stx-out, sbtc-out, token-out, profit, profitable }
     B -> STX (Alex) -> sBTC (Velar u70) -> B (Faktory)
   
   Look for:
   - Which amounts show profitable: true for each route
   - Which route has the highest profit at each amount
   - Compare Bitflow routes vs Velar u70 routes
   - Price impact as amount increases

✅ ACTUAL EXECUTION (100 B on all 4 routes):
   
   TEST 1 - arb-fak-bit-alex (Faktory -> Bitflow -> Alex)
     Returns: { token-in, token-out, burnt-token }
   
   TEST 2 - arb-alex-bit-fak (Alex -> Bitflow -> Faktory)
     Returns: { token-in, token-out, burnt-token }
   
   TEST 3 - arb-fak-vel-alex (Faktory -> Velar u70 -> Alex)
     Returns: { token-in, token-out, burnt-token }
   
   TEST 4 - arb-alex-vel-fak (Alex -> Velar u70 -> Faktory)
     Returns: { token-in, token-out, burnt-token }

Analysis:
1. Check simulations to find the sweet spot amount for each route
2. Compare profit between all 4 routes at each amount
3. Identify which route is most profitable
4. See if Velar u70 routes capture more B Blocks due to price inefficiency
5. Verify actual execution matches simulation
6. If all fail with ERR-NO-PROFIT, check smaller amounts

Key Questions Answered:
- Does Velar u70's shallow liquidity create exploitable price gaps?
- Do lower fees on Velar u70 (0.3% vs 0.5% Bitflow) offset slippage?
- Which route burns the most B Blocks?
- How does Alex's liquidity compare to what Velar provided for Pepe?

The simulation results will show you exactly which route and amount
maximizes B Block capture and burn!
*/

// https://stxer.xyz/simulations/mainnet/3be6baada37b019806dfa9faccb468ca
// all green
