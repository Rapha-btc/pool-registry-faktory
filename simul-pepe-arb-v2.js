import fs from "node:fs";
import { uintCV, ClarityVersion } from "@stacks/transactions";
import { SimulationBuilder } from "stxer";

const DEPLOYER = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22";
const PEPE_USER = "SP2022PJ05WB4VXP8HTVFAFE186AM94A4WYQ1RQY2"; // 710M PEPE (3 decimals)

const amounts = [
  1000000000n,  // 1M PEPE
  5000000000n,  // 5M PEPE
  12000000000n, // 12M PEPE
];

const checkFns = [
  "check-fak-bit-vel",  // PEPE->sBTC(fakfun) -> STX(bitflow) -> PEPE(velar)
  "check-fak-vel-vel",  // PEPE->sBTC(fakfun) -> STX(velar) -> PEPE(velar)
  "check-vel-bit-fak",  // PEPE->STX(velar) -> sBTC(bitflow) -> PEPE(fakfun)
  "check-vel-vel-fak",  // PEPE->STX(velar) -> sBTC(velar) -> PEPE(fakfun)
  "check-fak-bit-bit",  // PEPE->sBTC(fakfun) -> STX(bitflow) -> PEPE(bitflow)
  "check-fak-vel-bit",  // PEPE->sBTC(fakfun) -> STX(velar) -> PEPE(bitflow)
  "check-bit-bit-fak",  // PEPE->STX(bitflow) -> sBTC(bitflow) -> PEPE(fakfun)
  "check-bit-vel-fak",  // PEPE->STX(bitflow) -> sBTC(velar) -> PEPE(fakfun)
];

const arbFns = [
  "arb-fak-bit-vel",
  "arb-fak-vel-vel",
  "arb-vel-bit-fak",
  "arb-vel-vel-fak",
  "arb-fak-bit-bit",
  "arb-fak-vel-bit",
  "arb-bit-bit-fak",
  "arb-bit-vel-fak",
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

// Check all routes at all amounts
for (const amount of amounts) {
  for (const fn of checkFns) {
    builder.addEvalCode(
      `${DEPLOYER}.pepe-arbitrage-faktory-v2`,
      `(${fn} u${amount})`
    );
  }
}

// Execute all 8 routes with 1M PEPE
const EXEC_AMOUNT = 1000000000n;

for (const fn of arbFns) {
  builder.addContractCall({
    contract_id: `${DEPLOYER}.pepe-arbitrage-faktory-v2`,
    function_name: fn,
    function_args: [uintCV(EXEC_AMOUNT), uintCV(1)],
  });
}

builder.run().catch(console.error);

/*
Routes (naming: arb-{leg1}-{leg2}-{leg3}):
  fak = fakfun pool, bit = bitflow, vel = velar

  Velar PEPE-STX routes:
    fak-bit-vel: PEPE->sBTC(fakfun) -> STX(bitflow) -> PEPE(velar)
    fak-vel-vel: PEPE->sBTC(fakfun) -> STX(velar) -> PEPE(velar)
    vel-bit-fak: PEPE->STX(velar) -> sBTC(bitflow) -> PEPE(fakfun)
    vel-vel-fak: PEPE->STX(velar) -> sBTC(velar) -> PEPE(fakfun)

  Bitflow PEPE-STX routes:
    fak-bit-bit: PEPE->sBTC(fakfun) -> STX(bitflow) -> PEPE(bitflow)
    fak-vel-bit: PEPE->sBTC(fakfun) -> STX(velar) -> PEPE(bitflow)
    bit-bit-fak: PEPE->STX(bitflow) -> sBTC(bitflow) -> PEPE(fakfun)
    bit-vel-fak: PEPE->STX(bitflow) -> sBTC(velar) -> PEPE(fakfun)
*/
