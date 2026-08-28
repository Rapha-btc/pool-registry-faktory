// verify-welsh-smart.js
// Self-verifying stxer mainnet-fork harness for welsh-smart-faktory (DRAFT).
// Generated from verify-leo-smart.js; venues: welshcorgicoin-faktory-pool-v2 via
// fakfun-core-v2 (the "fak" leg) and, by flag, BitFlow xyk-pool-welsh-stx-v-1-1
// (x = WELSH, y = STX) or the ALEX 2-hop STX<->ALEX<->WELSH through
// amm-pool-v2-01 swap-helper-a (8-dec scaled *100 / /100).
//
// Pulls every result back and asserts it, so a regression is a non-zero exit.
// Covers the four core legs across both bridge flags (bitflow / velar) and
// the ratio extremes + split, the four smart-* wrappers, the read-only
// surface, and zero residue in the router.
//
// Run: node verify-welsh-smart.js
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
const C = `${DEPLOYER}.welsh-smart-faktory`;

// Funded mainnet principals, impersonated by the fork.
const SBTC_HOLDER = "SP2C7BCAP2NH3EYWCCVHJ6K0DMZBXDFKQ56KR7QN2"; // ~40 BTC
const STX_HOLDER = "SP9BP4PN74CNR5XT7CMAMBPA0GWC9HMB69HVVV51";
const WELSH_HOLDER = "SP3AP6DRSQ6P4FETB5M33D082Q2ABGJW60MT6103Q"; // ~745M WELSH (6dec)

const SBTC_AMOUNT = 100000n; // 100k sats
const STX_AMOUNT = 100000000n; // 100 STX (6dec)
const WELSH_AMOUNT = 100000000000n; // 100k WELSH (6dec)

const RATIOS = [0n, 50n, 100n];

const src = fs.readFileSync(process.env.SRC || "./contracts/welsh-smart-faktory.clar", "utf8");

let checks = 0;
let failures = 0;
const steps = [];
const expectOk = (label) => steps.push({ label, kind: "tx-ok" });
const expectEval = (label) => steps.push({ label, kind: "eval" });

const b = SimulationBuilder.new()
  .withSender(DEPLOYER)
  .addContractDeploy({
    contract_name: "welsh-smart-faktory",
    source_code: src,
    clarity_version: ClarityVersion.Clarity5,
  });
steps.push({ label: "deploy welsh-smart-faktory (Clarity 5)", kind: "deploy" });

// --- read-only surface -------------------------------------------------------
for (const [label, code] of [
  ["fak sbtc/token liquidity", "(get-fak-sbtc-token-liquidity)"],
  ["dex stx liquidity (flag true)", "(get-dex-stx-token-liquidity true)"],
  ["dex stx liquidity (flag false)", "(get-dex-stx-token-liquidity false)"],
  ["sim stx->token (flag true)", `(simulate-stx-to-token u${STX_AMOUNT} true)`],
  ["sim stx->token (flag false)", `(simulate-stx-to-token u${STX_AMOUNT} false)`],
  ["sim token->stx (flag true)", `(simulate-token-to-stx u${WELSH_AMOUNT} true)`],
  ["sim token->stx (flag false)", `(simulate-token-to-stx u${WELSH_AMOUNT} false)`],
  ["sim sbtc->token (fak pool)", `(simulate-sbtc-to-token u${SBTC_AMOUNT})`],
  ["sim token->sbtc (fak pool)", `(simulate-token-to-sbtc u${WELSH_AMOUNT})`],
  ["bitflow sbtc/stx liquidity", "(get-bit-sbtc-stx-liquidity)"],
  ["velar sbtc/stx liquidity", "(get-velar-sbtc-stx-liquidity)"],
  ["optimal ratio sbtc->token (bitflow)", "(calculate-optimal-ratio-sbtc-to-token true)"],
  ["optimal ratio sbtc->token (velar)", "(calculate-optimal-ratio-sbtc-to-token false)"],
  ["optimal ratio stx->token (bitflow)", "(calculate-optimal-ratio-stx-to-token true)"],
  ["optimal ratio stx->token (velar)", "(calculate-optimal-ratio-stx-to-token false)"],
  ["estimate sbtc->token", `(estimate-sbtc-to-token u${SBTC_AMOUNT} true)`],
  ["estimate stx->token", `(estimate-stx-to-token u${STX_AMOUNT} true)`],
  ["estimate token->sbtc", `(estimate-token-to-sbtc u${WELSH_AMOUNT} true)`],
  ["estimate token->stx", `(estimate-token-to-stx u${WELSH_AMOUNT} true)`],
  ["compare sbtc->token routes", `(compare-sbtc-to-token-routes u${SBTC_AMOUNT})`],
  ["compare stx->token routes", `(compare-stx-to-token-routes u${STX_AMOUNT})`],
  ["compare token->sbtc routes", `(compare-token-to-sbtc-routes u${WELSH_AMOUNT})`],
  ["compare token->stx routes", `(compare-token-to-stx-routes u${WELSH_AMOUNT})`],
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
    b.withSender(WELSH_HOLDER).addContractCall({
      contract_id: C,
      function_name: "sell-for-sbtc",
      function_args: [uintCV(WELSH_AMOUNT), uintCV(1), uintCV(ratio), boolCV(flag)],
    });
    expectOk(`sell-for-sbtc ratio=${ratio} ${venue(flag)}`);
  }
}
for (const flag of [true, false]) {
  for (const ratio of RATIOS) {
    b.withSender(WELSH_HOLDER).addContractCall({
      contract_id: C,
      function_name: "sell-for-stx",
      function_args: [uintCV(WELSH_AMOUNT), uintCV(1), uintCV(ratio), boolCV(flag)],
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
b.withSender(WELSH_HOLDER).addContractCall({
  contract_id: C, function_name: "smart-sell-for-sbtc",
  function_args: [uintCV(WELSH_AMOUNT), uintCV(1)],
});
expectOk("smart-sell-for-sbtc");
b.withSender(WELSH_HOLDER).addContractCall({
  contract_id: C, function_name: "smart-sell-for-stx",
  function_args: [uintCV(WELSH_AMOUNT), uintCV(1)],
});
expectOk("smart-sell-for-stx");

// --- zero residue -------------------------------------------------------------
for (const [label, code] of [
  ["residue STX", "(stx-get-balance current-contract)"],
  ["residue sBTC", "(contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token get-balance current-contract)"],
  ["residue WELSH", "(contract-call? 'SP3NE50GEXFG9SZGTT51P40X2CKYSZ5CC4ZTZ7A2G.welshcorgicoin-token get-balance current-contract)"],
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
