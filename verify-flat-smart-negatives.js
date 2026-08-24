// verify-flat-smart-negatives.js
// Error paths and the allowance-binding proof for flatearth-smart-faktory.
//
// The happy-path harness (verify-mia-smart.js) shows the correct allowances do
// not get in the way. It cannot show they DO anything. This one deploys a
// deliberately sabotaged twin whose allowance is one unit short of what the
// leg sends, and asserts that transaction aborts - so the allowances are
// demonstrably load-bearing rather than decorative.
//
// Run: node verify-flat-smart-negatives.js
import fs from "node:fs";
import {
  uintCV,
  boolCV,
  ClarityVersion,
  cvToString,
  deserializeCV,
} from "@stacks/transactions";
import { SimulationBuilder, getSimulationResult } from "stxer";

const DEPLOYER = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22";
const OK = `${DEPLOYER}.flatearth-smart-faktory`;
const SABOTAGED = `${DEPLOYER}.flat-smart-tight`;

const SBTC_HOLDER = "SP2C7BCAP2NH3EYWCCVHJ6K0DMZBXDFKQ56KR7QN2";
const STX_HOLDER = "SP9BP4PN74CNR5XT7CMAMBPA0GWC9HMB69HVVV51";
const MIA_HOLDER = "SP3W69VDG9VTZNG7NTW1QNCC1W45SNY98W1JSZBJH"; // 20k FLAT

const SBTC_AMOUNT = 100000n;
const STX_AMOUNT = 100000000n;
const MIA_AMOUNT = 20000000000n; // 20k FLAT

const ERR_SLIPPAGE = "u1000";
const ERR_INVALID_RATIO = "u1002";

const src = fs.readFileSync("./contracts/flatearth-smart-faktory.clar", "utf8");

// One unit short on the pure-fak sBTC leg. Everything else identical, so a
// difference in behaviour can only come from the allowance.
const tight = src.replace(
  "(as-contract? ((with-ft SBTC SBTC-ASSET fak-amount)) (try! (swap-sbtc-to-token fak-amount)))",
  "(as-contract? ((with-ft SBTC SBTC-ASSET (- fak-amount u1))) (try! (swap-sbtc-to-token fak-amount)))",
);
if (tight === src) {
  console.error("sabotage patch did not apply - the allowance text moved");
  process.exit(1);
}

const steps = [];
const b = SimulationBuilder.new()
  .withSender(DEPLOYER)
  .addContractDeploy({
    contract_name: "flatearth-smart-faktory",
    source_code: src,
    clarity_version: ClarityVersion.Clarity5,
  });
steps.push({ label: "deploy correct contract", want: (v) => v.startsWith("(ok") });

b.withSender(DEPLOYER).addContractDeploy({
  contract_name: "flat-smart-tight",
  source_code: tight,
  clarity_version: ClarityVersion.Clarity5,
});
steps.push({ label: "deploy under-declared twin", want: (v) => v.startsWith("(ok") });

// --- ERR-INVALID-RATIO: ratio 101 on each entry point ------------------------
const overRatio = [
  ["buy-with-sbtc", SBTC_HOLDER, SBTC_AMOUNT],
  ["buy-with-stx", STX_HOLDER, STX_AMOUNT],
  ["sell-for-sbtc", MIA_HOLDER, MIA_AMOUNT],
  ["sell-for-stx", MIA_HOLDER, MIA_AMOUNT],
];
for (const [fn, sender, amount] of overRatio) {
  b.withSender(sender).addContractCall({
    contract_id: OK,
    function_name: fn,
    function_args: [uintCV(amount), uintCV(1), uintCV(101n), boolCV(true)],
  });
  steps.push({
    label: `${fn} ratio=101 -> ERR-INVALID-RATIO`,
    want: (v) => v.includes(ERR_INVALID_RATIO),
  });
}

// --- ERR-SLIPPAGE: min-out set far above anything the split can return -------
const huge = 10n ** 30n;
for (const [fn, sender, amount] of overRatio) {
  b.withSender(sender).addContractCall({
    contract_id: OK,
    function_name: fn,
    function_args: [uintCV(amount), uintCV(huge), uintCV(50n), boolCV(true)],
  });
  steps.push({
    label: `${fn} min-out=1e30 -> ERR-SLIPPAGE`,
    want: (v) => v.includes(ERR_SLIPPAGE),
  });
}

// --- the allowance actually binds -------------------------------------------
// Same call, same inputs, on the twin whose allowance is 1 sat short. It must
// NOT return (ok ...). If this passes, the allowances are doing nothing.
b.withSender(SBTC_HOLDER).addContractCall({
  contract_id: SABOTAGED,
  function_name: "buy-with-sbtc",
  function_args: [uintCV(SBTC_AMOUNT), uintCV(1), uintCV(100n), boolCV(true)],
});
steps.push({
  label: "under-declared allowance aborts the tx",
  want: (v) => !v.startsWith("(ok"),
});

// Control: the identical call on the correct contract still succeeds, so the
// abort above is the allowance and not the trade being impossible.
b.withSender(SBTC_HOLDER).addContractCall({
  contract_id: OK,
  function_name: "buy-with-sbtc",
  function_args: [uintCV(SBTC_AMOUNT), uintCV(1), uintCV(100n), boolCV(true)],
});
steps.push({
  label: "control: same call with the correct allowance succeeds",
  want: (v) => v.startsWith("(ok"),
});

function decodeTx(s) {
  const r = s?.Result?.Transaction;
  if (!r) return "<no tx>";
  if ("Err" in r) return `ENGINE-ERR ${JSON.stringify(r.Err)}`;
  try {
    return cvToString(deserializeCV(r.Ok.result));
  } catch {
    return `raw:${r.Ok?.result}`;
  }
}

const sid = await b.run();
console.log(`\nView: https://stxer.xyz/simulations/mainnet/${sid}\n`);
const res = await getSimulationResult(sid);

let checks = 0;
let failures = 0;
steps.forEach((step, i) => {
  const v = decodeTx(res.steps[i]);
  checks += 1;
  const ok = step.want(String(v));
  if (!ok) failures += 1;
  console.log(`  ${ok ? "ok  " : "FAIL"} ${step.label}: ${String(v).slice(0, 120)}`);
});
console.log(`\n${checks - failures}/${checks} checks green`);
if (failures > 0) process.exit(1);
