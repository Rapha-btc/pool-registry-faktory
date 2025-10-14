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

// ===== SIMULATE ALL AMOUNTS FOR BOTH ROUTES =====
console.log("\n=== SIMULATING ARBITRAGE OPPORTUNITIES ===\n");

for (const amount of amounts) {
  builder
    // Simulate Route 1: PEPE -> sBTC -> STX -> PEPE
    .addEvalCode(
      `${DEPLOYER}.pepe-arbitrage-faktory`,
      `(check-arb-fak u${amount})`
    )
    // Simulate Route 2: PEPE -> STX -> sBTC -> PEPE
    .addEvalCode(
      `${DEPLOYER}.pepe-arbitrage-faktory`,
      `(check-arb-velar u${amount})`
    );
}

// ===== EXECUTE ACTUAL ARBITRAGE WITH 1.2M PEPE =====
const EXECUTION_AMOUNT = 1200000000n;

builder
  // ===== TEST ROUTE 1: PEPE -> sBTC -> STX -> PEPE =====
  .addContractCall({
    contract_id: `${DEPLOYER}.pepe-arbitrage-faktory`,
    function_name: "arb-sell-fak",
    function_args: [
      uintCV(EXECUTION_AMOUNT),
      uintCV(1), // min-pepe-out = 1
    ],
  })

  // ===== TEST ROUTE 2: PEPE -> STX -> sBTC -> PEPE =====
  .addContractCall({
    contract_id: `${DEPLOYER}.pepe-arbitrage-faktory`,
    function_name: "arb-sell-velar",
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

✅ SIMULATIONS (for each amount):
   - check-arb-fak returns: { pepe-in, sbtc-out, stx-out, pepe-out, profit, profitable }
   - check-arb-velar returns: { pepe-in, stx-out, sbtc-out, pepe-out, profit, profitable }
   
   Look for:
   - Which amounts show profitable: true
   - Which route has higher profit at each amount
   - Price impact as amount increases

✅ ACTUAL EXECUTION (12M PEPE):
   - TEST 1 - arb-sell-fak (PEPE -> sBTC -> STX -> PEPE)
     Returns: { pepe-in, pepe-out, burnt-pepe }
   
   - TEST 2 - arb-sell-velar (PEPE -> STX -> sBTC -> PEPE)
     Returns: { pepe-in, pepe-out, burnt-pepe }

Analysis:
1. Check simulations to find the sweet spot amount
2. Compare profit between routes
3. Verify actual execution matches simulation
4. If both fail with ERR-NO-PROFIT, check smaller amounts in simulations

The simulation results will show you exactly which amounts are profitable
and by how much, helping you optimize your arbitrage strategy!
*/

/// https://stxer.xyz/simulations/mainnet/087c9f4559f989e2a5c3529cb5909c68
