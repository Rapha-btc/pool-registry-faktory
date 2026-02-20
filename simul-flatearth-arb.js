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
    contract_name: "flatearth-arbitrage-faktory",
    source_code: fs.readFileSync(
      "./contracts/flatearth-arbitrage-faktory.clar",
      "utf8"
    ),
    clarity_version: ClarityVersion.Clarity3,
  })
  .withSender(TOKEN_USER);

console.log("\n=== FLATEARTH ARBITRAGE — 4 ROUTES ===\n");
console.log("NOTE: Bitflow STX-FLAT pool has reversed X/Y (STX=X, FLAT=Y)\n");

for (const amount of amounts) {
  for (let route = 1; route <= 4; route++) {
    builder.addEvalCode(
      `${DEPLOYER}.flatearth-arbitrage-faktory`,
      `(check-route-${route} u${amount})`
    );
  }
}

const EXEC_AMOUNT = 12000000000n;

for (let route = 1; route <= 4; route++) {
  builder.addContractCall({
    contract_id: `${DEPLOYER}.flatearth-arbitrage-faktory`,
    function_name: `simulate-route-${route}`,
    function_args: [uintCV(EXEC_AMOUNT)],
  });
}

builder.run().catch(console.error);

/*
Routes:
  1: sell-buy — FLAT->sBTC(fakfun) -> STX(bitflow) -> FLAT(bitflow STX-FLAT)
  2: buy-sell — FLAT->STX(bitflow STX-FLAT) -> sBTC(bitflow) -> FLAT(fakfun)
  3: sell-buy — FLAT->sBTC(fakfun) -> STX(velar) -> FLAT(velar pool 0003)
  4: buy-sell — FLAT->STX(velar pool 0003) -> sBTC(velar) -> FLAT(fakfun)
*/
