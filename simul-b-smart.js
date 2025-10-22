import fs from "node:fs";
import { uintCV, boolCV, ClarityVersion } from "@stacks/transactions";
import { SimulationBuilder } from "stxer";

// Define addresses
const DEPLOYER = "SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM";
const SBTC_HOLDER = "SP24MM95FEZJY3XWSBGZ5CT8DV04J6NVM5QA4WDXZ";
const STX_HOLDER = "SP2KZ24AM4X9HGTG8314MS4VSY1CVAFH0G1KBZZ1D";
const B_HOLDER = "SPWK34YZPVW724K9C8NRZA6VT4YDA2PB5SSD1VYF";

// Test amounts
const SBTC_AMOUNT = 100000n; // 100k sats of sBTC (8 decimals)
const STX_AMOUNT = 100000000n; // 100 STX (6 decimals)
const B_AMOUNT = 50000000000000n; // 500,000 B tokens (8 decimals)

// Test ratios
const RATIOS = [0n, 25n, 50n, 75n, 100n]; // 0%, 25%, 50%, 75%, 100%

// Build the simulation
const builder = SimulationBuilder.new()
  .withSender(DEPLOYER)

  // Deploy the smart contract
  .addContractDeploy({
    contract_name: "b-smart-faktory",
    source_code: fs.readFileSync("./contracts/b-smart-faktory.clar", "utf8"),
    clarity_version: ClarityVersion.Clarity3,
  });

// ===== PHASE 1: READ-ONLY CALLS TO GET LIQUIDITY INFORMATION =====
console.log("\n=== CHECKING LIQUIDITY INFO ===\n");

builder
  .addEvalCode(`${DEPLOYER}.b-smart-faktory`, `(get-fak-sbtc-token-liquidity)`)
  .addEvalCode(`${DEPLOYER}.b-smart-faktory`, `(get-alex-stx-token-liquidity)`)
  .addEvalCode(`${DEPLOYER}.b-smart-faktory`, `(get-bit-sbtc-stx-liquidity)`)
  .addEvalCode(`${DEPLOYER}.b-smart-faktory`, `(get-velar-sbtc-stx-liquidity)`);

// ===== PHASE 2: TEST OPTIMAL RATIO CALCULATIONS =====
console.log("\n=== TESTING OPTIMAL RATIO CALCULATIONS ===\n");

builder
  .addEvalCode(
    `${DEPLOYER}.b-smart-faktory`,
    `(calculate-optimal-ratio-sbtc-to-token true)` // Using BitFlow
  )
  .addEvalCode(
    `${DEPLOYER}.b-smart-faktory`,
    `(calculate-optimal-ratio-sbtc-to-token false)` // Using Velar
  )
  .addEvalCode(
    `${DEPLOYER}.b-smart-faktory`,
    `(calculate-optimal-ratio-stx-to-token true)` // Using BitFlow
  )
  .addEvalCode(
    `${DEPLOYER}.b-smart-faktory`,
    `(calculate-optimal-ratio-stx-to-token false)` // Using Velar
  );

// ===== PHASE 3: TEST ROUTE ESTIMATIONS AND COMPARISONS =====
console.log("\n=== TESTING ROUTE ESTIMATIONS ===\n");

builder
  // sBTC -> B token estimations
  .addEvalCode(
    `${DEPLOYER}.b-smart-faktory`,
    `(estimate-sbtc-to-token u${SBTC_AMOUNT} true)` // Using BitFlow
  )
  .addEvalCode(
    `${DEPLOYER}.b-smart-faktory`,
    `(estimate-sbtc-to-token u${SBTC_AMOUNT} false)` // Using Velar
  )
  .addEvalCode(
    `${DEPLOYER}.b-smart-faktory`,
    `(compare-sbtc-to-token-routes u${SBTC_AMOUNT})` // Compare routes
  )

  // STX -> B token estimations
  .addEvalCode(
    `${DEPLOYER}.b-smart-faktory`,
    `(estimate-stx-to-token u${STX_AMOUNT} true)` // Using BitFlow
  )
  .addEvalCode(
    `${DEPLOYER}.b-smart-faktory`,
    `(estimate-stx-to-token u${STX_AMOUNT} false)` // Using Velar
  )
  .addEvalCode(
    `${DEPLOYER}.b-smart-faktory`,
    `(compare-stx-to-token-routes u${STX_AMOUNT})` // Compare routes
  )

  // B token -> sBTC estimations
  .addEvalCode(
    `${DEPLOYER}.b-smart-faktory`,
    `(estimate-token-to-sbtc u${B_AMOUNT} true)` // Using BitFlow
  )
  .addEvalCode(
    `${DEPLOYER}.b-smart-faktory`,
    `(estimate-token-to-sbtc u${B_AMOUNT} false)` // Using Velar
  )
  .addEvalCode(
    `${DEPLOYER}.b-smart-faktory`,
    `(compare-token-to-sbtc-routes u${B_AMOUNT})` // Compare routes
  )

  // B token -> STX estimations
  .addEvalCode(
    `${DEPLOYER}.b-smart-faktory`,
    `(estimate-token-to-stx u${B_AMOUNT} true)` // Using BitFlow
  )
  .addEvalCode(
    `${DEPLOYER}.b-smart-faktory`,
    `(estimate-token-to-stx u${B_AMOUNT} false)` // Using Velar
  )
  .addEvalCode(
    `${DEPLOYER}.b-smart-faktory`,
    `(compare-token-to-stx-routes u${B_AMOUNT})` // Compare routes
  );

// ===== PHASE 4: TEST TRADING WITH DIFFERENT RATIOS =====
console.log("\n=== TESTING BUY/SELL FUNCTIONS WITH DIFFERENT RATIOS ===\n");

// sBTC -> B (buy with sBTC) tests
for (const flag of [true, false]) {
  // true = BitFlow, false = Velar
  for (const ratio of RATIOS) {
    builder.withSender(SBTC_HOLDER).addContractCall({
      contract_id: `${DEPLOYER}.b-smart-faktory`,
      function_name: "buy-with-sbtc",
      function_args: [
        uintCV(SBTC_AMOUNT),
        uintCV(1), // min-token-out = 1 (just for testing)
        uintCV(ratio), // fak-ratio
        boolCV(flag), // flag (true = BitFlow, false = Velar)
      ],
    });
  }
}

// STX -> B (buy with STX) tests
for (const flag of [true, false]) {
  // true = BitFlow, false = Velar
  for (const ratio of RATIOS) {
    builder.withSender(STX_HOLDER).addContractCall({
      contract_id: `${DEPLOYER}.b-smart-faktory`,
      function_name: "buy-with-stx",
      function_args: [
        uintCV(STX_AMOUNT),
        uintCV(1), // min-token-out = 1 (just for testing)
        uintCV(ratio), // alex-ratio
        boolCV(flag), // flag (true = BitFlow, false = Velar)
      ],
    });
  }
}

// B -> sBTC (sell for sBTC) tests
for (const flag of [true, false]) {
  // true = BitFlow, false = Velar
  for (const ratio of RATIOS) {
    builder.withSender(B_HOLDER).addContractCall({
      contract_id: `${DEPLOYER}.b-smart-faktory`,
      function_name: "sell-for-sbtc",
      function_args: [
        uintCV(B_AMOUNT),
        uintCV(1), // min-sbtc-out = 1 (just for testing)
        uintCV(ratio), // fak-ratio
        boolCV(flag), // flag (true = BitFlow, false = Velar)
      ],
    });
  }
}

// B -> STX (sell for STX) tests
for (const flag of [true, false]) {
  // true = BitFlow, false = Velar
  for (const ratio of RATIOS) {
    builder.withSender(B_HOLDER).addContractCall({
      contract_id: `${DEPLOYER}.b-smart-faktory`,
      function_name: "sell-for-stx",
      function_args: [
        uintCV(B_AMOUNT),
        uintCV(1), // min-stx-out = 1 (just for testing)
        uintCV(ratio), // alex-ratio
        boolCV(flag), // flag (true = BitFlow, false = Velar)
      ],
    });
  }
}

// ===== PHASE 5: TEST SMART ROUTING FUNCTIONS =====
console.log("\n=== TESTING SMART ROUTING FUNCTIONS ===\n");

builder
  .withSender(SBTC_HOLDER)
  .addContractCall({
    contract_id: `${DEPLOYER}.b-smart-faktory`,
    function_name: "smart-buy-with-sbtc",
    function_args: [
      uintCV(SBTC_AMOUNT),
      uintCV(1), // min-token-out = 1 (just for testing)
    ],
  })

  .withSender(STX_HOLDER)
  .addContractCall({
    contract_id: `${DEPLOYER}.b-smart-faktory`,
    function_name: "smart-buy-with-stx",
    function_args: [
      uintCV(STX_AMOUNT),
      uintCV(1), // min-token-out = 1 (just for testing)
    ],
  })

  .withSender(B_HOLDER)
  .addContractCall({
    contract_id: `${DEPLOYER}.b-smart-faktory`,
    function_name: "smart-sell-for-sbtc",
    function_args: [
      uintCV(B_AMOUNT),
      uintCV(1), // min-sbtc-out = 1 (just for testing)
    ],
  })

  .addContractCall({
    contract_id: `${DEPLOYER}.b-smart-faktory`,
    function_name: "smart-sell-for-stx",
    function_args: [
      uintCV(B_AMOUNT),
      uintCV(1), // min-stx-out = 1 (just for testing)
    ],
  });

builder.run().catch(console.error);

/*
Expected Results:

✅ Deploy b-smart-faktory contract

✅ LIQUIDITY INFO:
   - Faktory Pool sBTC liquidity
   - ALEX Pool STX liquidity
   - BitFlow Pool sBTC/STX liquidity
   - Velar Pool sBTC/STX liquidity

✅ OPTIMAL RATIO CALCULATIONS:
   - BitFlow optimal ratios between Faktory and ALEX routes
   - Velar optimal ratios between Faktory and ALEX routes
   - These will show how much of the trade should go through each path

✅ ROUTE ESTIMATIONS:
   - Compare output from different routes (BitFlow vs Velar)
   - See which route gives best returns for each asset pair
   - Test the route comparison functions

✅ TRADING WITH DIFFERENT RATIOS:
   - Test buy-with-sbtc with various FAK/ALEX split ratios
   - Test buy-with-stx with various FAK/ALEX split ratios
   - Test sell-for-sbtc with various FAK/ALEX split ratios
   - Test sell-for-stx with various FAK/ALEX split ratios
   - Compare results to see how ratio affects output amount

✅ SMART ROUTING:
   - Test if smart routing correctly identifies optimal route
   - Compare smart routing output with the best manual ratio setting
   - Verify smart routing produces better results than single-route trading

Key Insights to Look For:
1. What's the optimal split ratio for each trading pair?
2. Does BitFlow or Velar provide better rates for sBTC/STX?
3. How much better is split routing vs. single-route trading?
4. Are the optimal ratios close to the liquidity proportions?
5. Do smart routing functions correctly identify the best route?
*/

// all green https://stxer.xyz/simulations/mainnet/7c0ade34aeb4c1f89b056cf312bf05dc
// all green https://stxer.xyz/simulations/mainnet/28f93b8324f1a30408780dd58156642e
