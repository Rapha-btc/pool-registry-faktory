import fs from "node:fs";
import { uintCV, contractPrincipalCV, ClarityVersion } from "@stacks/transactions";
import { SimulationBuilder } from "stxer";

const DEPLOYER = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22";
const LEO_USER = "SP17A1AM4TNYFPAZ75Z84X3D6R2F6DTJBDJ6B0YF"; // 500M LEO (6 decimals)

const amounts = [
  90000000000n,   // 90K LEO
  190000000000n,  // 190K LEO
];

const checkFns = [
  "check-fak-bit-bit",  // LEO->sBTC(fakfun) -> STX(bitflow) -> LEO(bitflow)
  "check-fak-vel-vel",  // LEO->sBTC(fakfun) -> STX(velar) -> LEO(velar)
  "check-bit-bit-fak",  // LEO->STX(bitflow) -> sBTC(bitflow) -> LEO(fakfun)
  "check-vel-vel-fak",  // LEO->STX(velar) -> sBTC(velar) -> LEO(fakfun)
  "check-fak-bit-alex", // LEO->sBTC(fakfun) -> STX(bitflow) -> ALEX -> LEO(alex)
  "check-fak-vel-alex", // LEO->sBTC(fakfun) -> STX(velar) -> ALEX -> LEO(alex)
  "check-alex-bit-fak", // LEO->ALEX->STX(alex) -> sBTC(bitflow) -> LEO(fakfun)
  "check-alex-vel-fak", // LEO->ALEX->STX(alex) -> sBTC(velar) -> LEO(fakfun)
];

const arbFns = [
  "arb-fak-bit-bit",
  "arb-fak-vel-vel",
  "arb-bit-bit-fak",
  "arb-vel-vel-fak",
  "arb-fak-bit-alex",
  "arb-fak-vel-alex",
  "arb-alex-bit-fak",
  "arb-alex-vel-fak",
];

const source = fs.readFileSync("./contracts/leo-arbitrage-faktory-v2.clar", "utf8")
  .split("\n").filter(l => !l.trim().startsWith(";;") && l.trim() !== "").join("\n");

const builder = SimulationBuilder.new()
  .withSender(DEPLOYER)
  .addContractDeploy({
    contract_name: "leo-arbitrage-faktory-v2",
    source_code: source,
    clarity_version: ClarityVersion.Clarity3,
  })
  .addContractCall({
    contract_id: `${DEPLOYER}.fakfun-core-v2`,
    function_name: "approve-caller",
    function_args: [
      contractPrincipalCV(DEPLOYER, "leo-arbitrage-faktory-v2"),
    ],
  })
  .withSender(LEO_USER);

console.log("\n=== LEO ARBITRAGE v2 — 8 ROUTES ===\n");

for (const amount of amounts) {
  for (const fn of checkFns) {
    builder.addEvalCode(
      `${DEPLOYER}.leo-arbitrage-faktory-v2`,
      `(${fn} u${amount})`
    );
  }
}

const EXEC_AMOUNT = 90000000000n; // 90K LEO

for (const fn of arbFns) {
  builder.addContractCall({
    contract_id: `${DEPLOYER}.leo-arbitrage-faktory-v2`,
    function_name: fn,
    function_args: [uintCV(EXEC_AMOUNT), uintCV(1)],
  });
}

builder.run().catch(console.error);

/*
Routes (naming: arb-{leg1}-{leg2}-{leg3}):
  fak = fakfun pool, bit = bitflow, vel = velar, alex = ALEX DEX

  Bitflow LEO-STX routes:
    fak-bit-bit: LEO->sBTC(fakfun) -> STX(bitflow) -> LEO(bitflow)
    bit-bit-fak: LEO->STX(bitflow) -> sBTC(bitflow) -> LEO(fakfun)

  Velar LEO-STX routes (router u28):
    fak-vel-vel: LEO->sBTC(fakfun) -> STX(velar) -> LEO(velar)
    vel-vel-fak: LEO->STX(velar) -> sBTC(velar) -> LEO(fakfun)

  ALEX LEO-STX routes (2-hop: STX ↔ ALEX token ↔ LEO):
    fak-bit-alex: LEO->sBTC(fakfun) -> STX(bitflow) -> ALEX -> LEO(alex)
    fak-vel-alex: LEO->sBTC(fakfun) -> STX(velar) -> ALEX -> LEO(alex)
    alex-bit-fak: LEO->ALEX->STX(alex) -> sBTC(bitflow) -> LEO(fakfun)
    alex-vel-fak: LEO->ALEX->STX(alex) -> sBTC(velar) -> LEO(fakfun)
*/
