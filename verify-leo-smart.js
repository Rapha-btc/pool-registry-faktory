// verify-leo-smart.js
// Self-verifying stxer mainnet-fork harness for leo-smart-faktory (DRAFT).
// Generated from verify-fakfun-smart.js; venues: leo-faktory-pool-v2 via
// fakfun-core-v2 (the "fak" leg) and the ALEX 2-hop STX<->ALEX<->LEO through
// amm-pool-v2-01 swap-helper-a (the "alex" leg, 8-dec scaled *100 / /100).
//
// Pulls every result back and asserts it, so a regression is a non-zero exit.
// Covers the four core legs across both bridge flags (bitflow / velar) and
// the ratio extremes + split, the four smart-* wrappers, the read-only
// surface, and zero residue in the router.
//
// Run: node verify-leo-smart.js
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
const C = `${DEPLOYER}.leo-smart-faktory`;

// Funded mainnet principals, impersonated by the fork.
const SBTC_HOLDER = "SP2C7BCAP2NH3EYWCCVHJ6K0DMZBXDFKQ56KR7QN2"; // ~40 BTC
const STX_HOLDER = "SP9BP4PN74CNR5XT7CMAMBPA0GWC9HMB69HVVV51";
const LEO_HOLDER = "SP17A1AM4TNYFPAZ75Z84X3D6R2F6DTJBDJ6B0YF"; // ~500M LEO (6dec)

const SBTC_AMOUNT = 100000n; // 100k sats
const STX_AMOUNT = 100000000n; // 100 STX (6dec)
const LEO_AMOUNT = 100000000000n; // 100k LEO (6dec)

const RATIOS = [0n, 50n, 100n];

const src = fs.readFileSync(process.env.SRC || "./contracts/leo-smart-faktory.clar", "utf8");

let checks = 0;
let failures = 0;
const steps = [];
const expectOk = (label) => steps.push({ label, kind: "tx-ok" });
const expectEval = (label) => steps.push({ label, kind: "eval" });

const b = SimulationBuilder.new()
  .withSender(DEPLOYER)
  .addContractDeploy({
    contract_name: "leo-smart-faktory",
    source_code: src,
    clarity_version: ClarityVersion.Clarity5,
  });
steps.push({ label: "deploy leo-smart-faktory (Clarity 5)", kind: "deploy" });

// --- read-only surface -------------------------------------------------------
for (const [label, code] of [
  ["fak sbtc/token liquidity", "(get-fak-sbtc-token-liquidity)"],
  ["dex stx liquidity proxy (alex stx/alex hop)", "(get-dex-stx-token-liquidity true)"],
  ["sim stx->token (alex 2-hop)", `(simulate-stx-to-token u${STX_AMOUNT} true)`],
  ["sim token->stx (alex 2-hop)", `(simulate-token-to-stx u${LEO_AMOUNT} true)`],
  ["sim sbtc->token (leo pool)", `(simulate-sbtc-to-token u${SBTC_AMOUNT})`],
  ["sim token->sbtc (leo pool, haircut)", `(simulate-token-to-sbtc u${LEO_AMOUNT})`],
  ["bitflow sbtc/stx liquidity", "(get-bit-sbtc-stx-liquidity)"],
  ["velar sbtc/stx liquidity", "(get-velar-sbtc-stx-liquidity)"],
  ["optimal ratio sbtc->token (bitflow)", "(calculate-optimal-ratio-sbtc-to-token true)"],
  ["optimal ratio sbtc->token (velar)", "(calculate-optimal-ratio-sbtc-to-token false)"],
  ["optimal ratio stx->token (bitflow)", "(calculate-optimal-ratio-stx-to-token true)"],
  ["optimal ratio stx->token (velar)", "(calculate-optimal-ratio-stx-to-token false)"],
  ["estimate sbtc->token", `(estimate-sbtc-to-token u${SBTC_AMOUNT} true)`],
  ["estimate stx->token", `(estimate-stx-to-token u${STX_AMOUNT} true)`],
  ["estimate token->sbtc", `(estimate-token-to-sbtc u${LEO_AMOUNT} true)`],
  ["estimate token->stx", `(estimate-token-to-stx u${LEO_AMOUNT} true)`],
  ["compare sbtc->token routes", `(compare-sbtc-to-token-routes u${SBTC_AMOUNT})`],
  ["compare stx->token routes", `(compare-stx-to-token-routes u${STX_AMOUNT})`],
  ["compare token->sbtc routes", `(compare-token-to-sbtc-routes u${LEO_AMOUNT})`],
  ["compare token->stx routes", `(compare-token-to-stx-routes u${LEO_AMOUNT})`],
]) {
  b.addEvalCode(C, code);
  expectEval(label);
}

// --- the four core legs, both bridges, ratio extremes + split ----------------
const venue = (f) => (f ? "bitflow" : "velar");
for (const flag of [true, false]) {
  for (const ratio of RATIOS) {
    b.withSender(SBTC_HOLDER).addContractCall({
      contract_id: C,
      function_name: "buy-with-sbtc",
      function_args: [uintCV(SBTC_AMOUNT), uintCV(1), uintCV(ratio), boolCV(flag)],
    });
    expectOk(`buy-with-sbtc ratio=${ratio} ${venue(flag)}`);
  }
}
for (const flag of [true, false]) {
  for (const ratio of RATIOS) {
    b.withSender(STX_HOLDER).addContractCall({
      contract_id: C,
      function_name: "buy-with-stx",
      function_args: [uintCV(STX_AMOUNT), uintCV(1), uintCV(ratio), boolCV(flag)],
    });
    expectOk(`buy-with-stx ratio=${ratio} ${venue(flag)}`);
  }
}
for (const flag of [true, false]) {
  for (const ratio of RATIOS) {
    b.withSender(LEO_HOLDER).addContractCall({
      contract_id: C,
      function_name: "sell-for-sbtc",
      function_args: [uintCV(LEO_AMOUNT), uintCV(1), uintCV(ratio), boolCV(flag)],
    });
    expectOk(`sell-for-sbtc ratio=${ratio} ${venue(flag)}`);
  }
}
for (const flag of [true, false]) {
  for (const ratio of RATIOS) {
    b.withSender(LEO_HOLDER).addContractCall({
      contract_id: C,
      function_name: "sell-for-stx",
      function_args: [uintCV(LEO_AMOUNT), uintCV(1), uintCV(ratio), boolCV(flag)],
    });
    expectOk(`sell-for-stx ratio=${ratio} ${venue(flag)}`);
  }
}

// --- smart-* wrappers --------------------------------------------------------
b.withSender(SBTC_HOLDER).addContractCall({
  contract_id: C, function_name: "smart-buy-with-sbtc",
  function_args: [uintCV(SBTC_AMOUNT), uintCV(1)],
});
expectOk("smart-buy-with-sbtc");
b.withSender(STX_HOLDER).addContractCall({
  contract_id: C, function_name: "smart-buy-with-stx",
  function_args: [uintCV(STX_AMOUNT), uintCV(1)],
});
expectOk("smart-buy-with-stx");
b.withSender(LEO_HOLDER).addContractCall({
  contract_id: C, function_name: "smart-sell-for-sbtc",
  function_args: [uintCV(LEO_AMOUNT), uintCV(1)],
});
expectOk("smart-sell-for-sbtc");
b.withSender(LEO_HOLDER).addContractCall({
  contract_id: C, function_name: "smart-sell-for-stx",
  function_args: [uintCV(LEO_AMOUNT), uintCV(1)],
});
expectOk("smart-sell-for-stx");

// --- zero residue -------------------------------------------------------------
for (const [label, code] of [
  ["residue STX", "(stx-get-balance current-contract)"],
  ["residue sBTC", "(contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token get-balance current-contract)"],
  ["residue LEO", "(contract-call? 'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token get-balance current-contract)"],
]) {
  b.addEvalCode(C, code);
  steps.push({ label, kind: "residue" });
}

function decodeTx(s) {
  const r = s?.Result?.Transaction;
  if (!r) return "<no tx>";
  if ("Err" in r) return `ENGINE-ERR ${JSON.stringify(r.Err)}`;
  try { return cvToString(deserializeCV(r.Ok.result)); } catch { return `raw:${r.Ok?.result}`; }
}
function decodeEval(s) {
  const r = s?.Result?.Eval;
  if (!r) return "<no eval>";
  if (!("Ok" in r)) return `ERR ${JSON.stringify(r.Err)}`;
  try { return cvToString(deserializeCV(r.Ok)); } catch { return r.Ok; }
}
function assert(label, actual, ok) {
  checks += 1;
  if (ok) console.log(`  ok   ${label}: ${String(actual).slice(0, 110)}`);
  else { failures += 1; console.log(`  FAIL ${label}: ${String(actual).slice(0, 200)}`); }
}

const sid = await b.run();
console.log(`\nView: https://stxer.xyz/simulations/mainnet/${sid}\n`);
const res = await getSimulationResult(sid);

steps.forEach((step, i) => {
  const s = res.steps[i];
  if (step.kind === "eval") {
    const v = decodeEval(s);
    assert(step.label, v, !String(v).startsWith("ERR") && v !== "<no eval>");
  } else if (step.kind === "residue") {
    const v = decodeEval(s);
    assert(step.label, v, v === "u0" || v === "(ok u0)");
  } else {
    const v = decodeTx(s);
    assert(step.label, v, String(v).startsWith("(ok"));
  }
});

console.log(`\n${checks - failures}/${checks} checks green`);
if (failures > 0) process.exit(1);
