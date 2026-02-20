import fs from "node:fs";
import { uintCV, ClarityVersion } from "@stacks/transactions";
import { SimulationBuilder } from "stxer";

const DEPLOYER = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22";
const PEPE_USER = "SP3YM5YRTKHTWRC82K5DZJBY9XW0K4AX0P9PM5VSH";

const amounts = [
  1000000000n,  // 1M PEPE
  5000000000n,  // 5M PEPE
  12000000000n, // 12M PEPE
];

const builder = SimulationBuilder.new()
  .withSender(DEPLOYER)
  .addContractDeploy({
    contract_name: "pepe-arbitrage-faktory-v2",
    source_code: fs.readFileSync(
      "./contracts/pepe-arbitrage-faktory-v2.clar",
      "utf8"
    ),
    clarity_version: ClarityVersion.Clarity3,
  })
  .withSender(PEPE_USER);

console.log("\n=== PEPE v2 ARBITRAGE — 8 ROUTES ===\n");

for (const amount of amounts) {
  for (let route = 1; route <= 8; route++) {
    builder.addEvalCode(
      `${DEPLOYER}.pepe-arbitrage-faktory-v2`,
      `(check-route-${route} u${amount})`
    );
  }
}

// Execute simulations with 12M PEPE on all 8 routes
const EXEC_AMOUNT = 12000000000n;

for (let route = 1; route <= 8; route++) {
  builder.addContractCall({
    contract_id: `${DEPLOYER}.pepe-arbitrage-faktory-v2`,
    function_name: `simulate-route-${route}`,
    function_args: [uintCV(EXEC_AMOUNT)],
  });
}

builder.run().catch(console.error);

/*
Routes:
  1: sell-buy — PEPE->sBTC(fakfun) -> STX(bitflow) -> PEPE(bitflow)
  2: buy-sell — PEPE->STX(bitflow) -> sBTC(bitflow) -> PEPE(fakfun)
  3: sell-buy — PEPE->sBTC(fakfun) -> STX(velar) -> PEPE(bitflow)
  4: buy-sell — PEPE->STX(bitflow) -> sBTC(velar) -> PEPE(fakfun)
  5: sell-buy — PEPE->sBTC(fakfun) -> STX(bitflow) -> PEPE(velar)
  6: buy-sell — PEPE->STX(velar) -> sBTC(bitflow) -> PEPE(fakfun)
  7: sell-buy — PEPE->sBTC(fakfun) -> STX(velar) -> PEPE(velar)
  8: buy-sell — PEPE->STX(velar) -> sBTC(velar) -> PEPE(fakfun)
*/
