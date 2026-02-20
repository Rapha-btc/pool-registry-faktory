import fs from "node:fs";
import { uintCV, ClarityVersion } from "@stacks/transactions";
import { SimulationBuilder } from "stxer";

const DEPLOYER = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22";
const TOKEN_USER = "SP3YM5YRTKHTWRC82K5DZJBY9XW0K4AX0P9PM5VSH";

const amounts = [
  1000000000n,  // 1M
  5000000000n,  // 5M
  12000000000n, // 12M
];

const builder = SimulationBuilder.new()
  .withSender(DEPLOYER)
  .addContractDeploy({
    contract_name: "leo-arbitrage-faktory",
    source_code: fs.readFileSync(
      "./contracts/leo-arbitrage-faktory.clar",
      "utf8"
    ),
    clarity_version: ClarityVersion.Clarity3,
  })
  .withSender(TOKEN_USER);

console.log("\n=== LEO ARBITRAGE — 4 ROUTES ===\n");

for (const amount of amounts) {
  for (let route = 1; route <= 4; route++) {
    builder.addEvalCode(
      `${DEPLOYER}.leo-arbitrage-faktory`,
      `(check-route-${route} u${amount})`
    );
  }
}

const EXEC_AMOUNT = 12000000000n;

for (let route = 1; route <= 4; route++) {
  builder.addContractCall({
    contract_id: `${DEPLOYER}.leo-arbitrage-faktory`,
    function_name: `simulate-route-${route}`,
    function_args: [uintCV(EXEC_AMOUNT)],
  });
}

builder.run().catch(console.error);

/*
Routes:
  1: sell-buy — LEO->sBTC(fakfun) -> STX(bitflow) -> LEO(bitflow)
  2: buy-sell — LEO->STX(bitflow) -> sBTC(bitflow) -> LEO(fakfun)
  3: sell-buy — LEO->sBTC(fakfun) -> STX(velar) -> LEO(velar u28)
  4: buy-sell — LEO->STX(velar u28) -> sBTC(velar) -> LEO(fakfun)
*/
