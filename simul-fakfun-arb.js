// simul-fakfun-arb.js
// Mainnet-fork stxer sim for fakfun-arbitrage-faktory (DRAFT, deployed fresh
// in the fork as Clarity 5). Modeled on simul-flatearth-arb-v2.js.
//
// FAKFUN venues: Charisma sBTC pool (via fakfun-core-v2) and the bitflow
// xyk FAKFUN/STX pool. All four routes are checked (read-only) across sizes
// and then executed with min-out u1, so the only legitimate refusal is
// ERR-NO-PROFIT (u1001). The whale FAKFUN holder is impersonated directly as
// the executor, so no funding step is needed; profit lands with DEPLOYER.
//
// Run:  node simul-fakfun-arb.js
//       SRC=./contracts/d-fakfun-arbitrage-faktory.clar node simul-fakfun-arb.js  (deploy variant)

import fs from "node:fs";
import { uintCV, ClarityVersion, hexToCV, cvToJSON } from "@stacks/transactions";
import { SimulationBuilder, getSimulationResult } from "stxer";

const DEPLOYER = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22"; // deploys the arb; receives profit
const SENDER = "SP3Q7W8W5FGFJGGWEKVW4PQ8MYTR3EMYQRJFN2RRC"; // ~34.8M FAKFUN, impersonated executor
const ARB_NAME = "fakfun-arbitrage-faktory";
const ARB = `${DEPLOYER}.${ARB_NAME}`;

const DEC = 8n; // FAKFUN decimals
const tok = (n) => BigInt(n) * 10n ** DEC;

// The bitflow FAKFUN/STX pool is thin (~135 STX), so keep sizes modest.
const CHECK_SIZES = [5_000, 20_000, 50_000];
const EXEC_SIZES = [5_000, 20_000, 50_000];

const ROUTES = [
  { key: "fak-bit-bit", check: "check-fak-bit-bit", arb: "arb-fak-bit-bit" },
  { key: "fak-vel-bit", check: "check-fak-vel-bit", arb: "arb-fak-vel-bit" },
  { key: "bit-bit-fak", check: "check-bit-bit-fak", arb: "arb-bit-bit-fak" },
  { key: "bit-vel-fak", check: "check-bit-vel-fak", arb: "arb-bit-vel-fak" },
];

const b = SimulationBuilder.new()
  .withSender(DEPLOYER)
  .addContractDeploy({
    contract_name: ARB_NAME,
    source_code: fs.readFileSync(process.env.SRC || "./contracts/fakfun-arbitrage-faktory.clar", "utf8"),
    clarity_version: ClarityVersion.Clarity5,
  });

// 1) read-only profit checks across sizes, all routes
const checkPlan = [];
for (const r of ROUTES) {
  for (const s of CHECK_SIZES) {
    b.addEvalCode(ARB, `(${r.check} u${tok(s)})`);
    checkPlan.push({ route: r.key, size: s });
  }
}

// 2) executions; min-out u1 so only ERR-NO-PROFIT can stop a leg
const execPlan = [];
b.withSender(SENDER);
for (const r of ROUTES) {
  for (const s of EXEC_SIZES) {
    b.addContractCall({
      contract_id: ARB,
      function_name: r.arb,
      function_args: [uintCV(tok(s)), uintCV(1n)],
    });
    execPlan.push({ route: r.key, arb: r.arb, size: s });
  }
}

const num = (v) => (typeof v === "object" && v && "value" in v ? v.value : v);

async function main() {
  console.log("=== FAKFUN ARB - mainnet-fork sim (Charisma <-> bitflow xyk) ===\n");
  const id = await b.run();
  console.log("session:", id);
  console.log("view:   https://stxer.xyz/simulations/mainnet/" + id + "\n");

  const res = await getSimulationResult(id);
  const evals = [];
  const txs = [];
  for (const step of res.steps) {
    if (step.Eval && step.Result?.Eval) {
      const [, , contract, code] = step.Eval;
      evals.push({ contract, code, ...step.Result.Eval });
    } else if (step.Result?.Transaction) {
      const t = step.Result.Transaction;
      if (t.Ok) txs.push({ ok: true, receipt: t.Ok, result: t.Ok.result });
      else txs.push({ ok: false, err: t.Err });
    }
  }

  // deploy must have landed
  const deployTx = txs[0];
  if (!deployTx?.ok || deployTx.receipt?.vm_error) {
    console.log("DEPLOY FAILED:", JSON.stringify(deployTx).slice(0, 300));
    process.exitCode = 1;
    return;
  }
  console.log("deploy: ok (Clarity 5)\n");

  console.log("--- profit curve (read-only checks) ---");
  const checkEvals = evals.filter((e) => e.contract === ARB);
  let garbageCount = 0;
  let evalErrs = 0;
  checkEvals.forEach((e, i) => {
    const plan = checkPlan[i];
    if (!plan) return;
    if (e.Err) {
      console.log(`  ${plan.route} @ ${plan.size} FAKFUN -> EVAL ERR: ${JSON.stringify(e.Err).slice(0, 120)}`);
      evalErrs++;
      return;
    }
    const j = cvToJSON(hexToCV(e.Ok)).value.value;
    const profit = num(j.profit.value);
    const profitable = j.profitable.value;
    const outTok = Number(num(j["token-out"].value)) / 1e8;
    const garbage = outTok > plan.size * 5;
    if (garbage) garbageCount++;
    console.log(
      `  ${plan.route.padEnd(11)} @ ${String(plan.size).padStart(6)} FAKFUN -> out ${outTok.toFixed(0)} | profit ${profit} (${profitable === true || profitable === "true" ? "PROFITABLE" : "no"})` +
        (garbage ? "  GARBAGE" : ""),
    );
  });
  console.log(garbageCount === 0 && evalErrs === 0 ? "  ok: all checks sane" : `  FAIL: ${garbageCount} garbage, ${evalErrs} eval errors`);

  console.log("\n--- executions (behavior verification) ---");
  let failures = 0;
  const execTxs = txs.slice(-execPlan.length);
  execTxs.forEach((t, i) => {
    const plan = execPlan[i];
    if (!plan) return;
    if (!t.ok) { console.log(`  ${plan.arb} @ ${plan.size}: engine-level ERR ${JSON.stringify(t.err).slice(0, 160)}`); failures++; return; }
    const r = t.receipt;
    if (r.post_condition_aborted) { console.log(`  ${plan.arb} @ ${plan.size}: POST-CONDITION ABORT`); failures++; return; }
    if (r.vm_error) { console.log(`  ${plan.arb} @ ${plan.size}: VM ERROR ${r.vm_error}`); failures++; return; }
    let cv;
    try { cv = cvToJSON(hexToCV(t.result)); } catch { console.log(`  ${plan.arb} @ ${plan.size}: undecodable ${t.result}`); failures++; return; }
    if (cv.success === true) {
      const tup = cv.value?.value ?? {};
      const tin = num(tup["token-in"]?.value);
      const tout = num(tup["token-out"]?.value);
      const good = tout != null && BigInt(tout) > BigInt(tin);
      console.log(`  ${plan.arb} @ ${plan.size}: OK  in=${tin} out=${tout} ${good ? "(profit ok)" : "(NOT > in FAIL)"}`);
      if (!good) failures++;
    } else {
      const errCode = String(cv.value?.value ?? "?");
      const label = errCode === "1001" ? "ERR-NO-PROFIT (correct refusal)" : errCode === "1000" ? "ERR-SLIPPAGE" : "UNEXPECTED";
      console.log(`  ${plan.arb} @ ${plan.size}: (err u${errCode}) = ${label}`);
      if (errCode !== "1001" && errCode !== "1000") failures++;
    }
  });

  const ok = failures === 0 && garbageCount === 0 && evalErrs === 0;
  console.log(`\n=== ${ok ? "PASS - checks sane + behavior as intended" : `FAIL - ${failures} bad exec, ${garbageCount} garbage, ${evalErrs} eval errs`} ===`);
  if (!ok) process.exitCode = 1;
}

main().catch((e) => { console.error(e); process.exitCode = 1; });
