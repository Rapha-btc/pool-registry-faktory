// verify-fakfun-smart.js
// Self-verifying stxer mainnet-fork harness for fakfun-smart-faktory (DRAFT).
// Generated from verify-flat-smart.js; venues: Charisma sBTC pool via fakfun-core-v2
// (the "fak" leg) and bitflow xyk FAKFUN/STX (the "alex" leg).
//
// Unlike simul-b-smart.js (which prints and leaves you to read the output),
// this pulls every result back and asserts it, so a regression is a non-zero
// exit rather than something you have to spot by eye.
//
// What it covers: the four core legs (buy-with-sbtc, buy-with-stx,
// sell-for-sbtc, sell-for-stx) across both DEX flags (bitflow / velar) and
// the ratio extremes, plus the four smart-* wrappers and the read-only
// surface. Every write path runs under the Clarity 5 as-contract? allowances,
// so an allowance that is too tight shows up here as a failing leg.
//
// Run: node verify-fakfun-smart.js
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
const C = `${DEPLOYER}.fakfun-smart-faktory`;

// Funded mainnet principals, impersonated by the fork.
const SBTC_HOLDER = "SP2C7BCAP2NH3EYWCCVHJ6K0DMZBXDFKQ56KR7QN2"; // ~40 BTC
const STX_HOLDER = "SP9BP4PN74CNR5XT7CMAMBPA0GWC9HMB69HVVV51";
const MIA_HOLDER = "SP3Q7W8W5FGFJGGWEKVW4PQ8MYTR3EMYQRJFN2RRC"; // ~34.8M FAKFUN (8dec)

const SBTC_AMOUNT = 100000n; // 100k sats
const STX_AMOUNT = 100000000n; // 100 STX (6dec)
const MIA_AMOUNT = 10000000000000n; // 100k FAKFUN (8dec)

// 0 and 100 are the single-venue extremes; 50 exercises the split path where
// both legs run and the allowances have to hold for each.
const RATIOS = [0n, 50n, 100n];

// SRC=./contracts/d-fakfun-smart-faktory.clar node ... runs the comment-stripped deploy variant.
const src = fs.readFileSync(process.env.SRC || "./contracts/fakfun-smart-faktory.clar", "utf8");

let checks = 0;
let failures = 0;
const steps = [];

function expectOk(label) {
  steps.push({ label, kind: "tx-ok" });
}
function expectEval(label) {
  steps.push({ label, kind: "eval" });
}

const b = SimulationBuilder.new()
  .withSender(DEPLOYER)
  .addContractDeploy({
    contract_name: "fakfun-smart-faktory",
    source_code: src,
    // Clarity 5: as-contract? with with-ft / with-stx allowances.
    clarity_version: ClarityVersion.Clarity5,
  });
steps.push({ label: "deploy fakfun-smart-faktory (Clarity 5)", kind: "deploy" });

// --- read-only surface -------------------------------------------------------
for (const [label, code] of [
  ["fak sbtc/token liquidity", "(get-fak-sbtc-token-liquidity)"],
  ["dex stx/token liquidity (bitflow)", "(get-dex-stx-token-liquidity true)"],
  ["dex stx/token liquidity (velar)", "(get-dex-stx-token-liquidity false)"],
  ["sim stx->token (bitflow xyk)", `(simulate-stx-to-token u${STX_AMOUNT} true)`],
  ["sim token->stx (bitflow xyk)", `(simulate-token-to-stx u${MIA_AMOUNT} true)`],
  ["sim sbtc->token (charisma)", `(simulate-sbtc-to-token u${SBTC_AMOUNT})`],
  ["sim token->sbtc (charisma)", `(simulate-token-to-sbtc u${MIA_AMOUNT})`],
  ["bitflow sbtc/stx liquidity", "(get-bit-sbtc-stx-liquidity)"],
  ["velar sbtc/stx liquidity", "(get-velar-sbtc-stx-liquidity)"],
  ["optimal ratio sbtc->token (bitflow)", "(calculate-optimal-ratio-sbtc-to-token true)"],
  ["optimal ratio sbtc->token (velar)", "(calculate-optimal-ratio-sbtc-to-token false)"],
  ["optimal ratio stx->token (bitflow)", "(calculate-optimal-ratio-stx-to-token true)"],
  ["optimal ratio stx->token (velar)", "(calculate-optimal-ratio-stx-to-token false)"],
  ["estimate sbtc->token", `(estimate-sbtc-to-token u${SBTC_AMOUNT} true)`],
  ["estimate stx->token", `(estimate-stx-to-token u${STX_AMOUNT} true)`],
  ["estimate token->sbtc", `(estimate-token-to-sbtc u${MIA_AMOUNT} true)`],
  ["estimate token->stx", `(estimate-token-to-stx u${MIA_AMOUNT} true)`],
  ["compare sbtc->token routes", `(compare-sbtc-to-token-routes u${SBTC_AMOUNT})`],
  ["compare stx->token routes", `(compare-stx-to-token-routes u${STX_AMOUNT})`],
  ["compare token->sbtc routes", `(compare-token-to-sbtc-routes u${MIA_AMOUNT})`],
  ["compare token->stx routes", `(compare-token-to-stx-routes u${MIA_AMOUNT})`],
]) {
  b.addEvalCode(C, code);
  expectEval(label);
}

// --- the four core legs, both venues, ratio extremes + split -----------------
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
    b.withSender(MIA_HOLDER).addContractCall({
      contract_id: C,
      function_name: "sell-for-sbtc",
      function_args: [uintCV(MIA_AMOUNT), uintCV(1), uintCV(ratio), boolCV(flag)],
    });
    expectOk(`sell-for-sbtc ratio=${ratio} ${venue(flag)}`);
  }
}
for (const flag of [true, false]) {
  for (const ratio of RATIOS) {
    b.withSender(MIA_HOLDER).addContractCall({
      contract_id: C,
      function_name: "sell-for-stx",
      function_args: [uintCV(MIA_AMOUNT), uintCV(1), uintCV(ratio), boolCV(flag)],
    });
    expectOk(`sell-for-stx ratio=${ratio} ${venue(flag)}`);
  }
}

// --- smart-* wrappers (contract picks the ratio and venue itself) ------------
b.withSender(SBTC_HOLDER).addContractCall({
  contract_id: C,
  function_name: "smart-buy-with-sbtc",
  function_args: [uintCV(SBTC_AMOUNT), uintCV(1)],
});
expectOk("smart-buy-with-sbtc");
b.withSender(STX_HOLDER).addContractCall({
  contract_id: C,
  function_name: "smart-buy-with-stx",
  function_args: [uintCV(STX_AMOUNT), uintCV(1)],
});
expectOk("smart-buy-with-stx");
b.withSender(MIA_HOLDER).addContractCall({
  contract_id: C,
  function_name: "smart-sell-for-sbtc",
  function_args: [uintCV(MIA_AMOUNT), uintCV(1)],
});
expectOk("smart-sell-for-sbtc");
b.withSender(MIA_HOLDER).addContractCall({
  contract_id: C,
  function_name: "smart-sell-for-stx",
  function_args: [uintCV(MIA_AMOUNT), uintCV(1)],
});
expectOk("smart-sell-for-stx");


// --- zero residue: nothing may be left in the router after all of the above --
// Every leg pays out exactly what it received; dust here means the fee shave
// or a payout is wrong. STX is native; sBTC and the token are SIP-010 reads.
for (const [label, code] of [
  ["residue STX", "(stx-get-balance current-contract)"],
  ["residue sBTC", "(contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token get-balance current-contract)"],
  ["residue token", "(contract-call? 'SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22.fakfun-faktory get-balance current-contract)"],
]) {
  b.addEvalCode(C, code);
  steps.push({ label, kind: "residue" });
}

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
function decodeEval(s) {
  const r = s?.Result?.Eval;
  if (!r) return "<no eval>";
  if (!("Ok" in r)) return `ERR ${JSON.stringify(r.Err)}`;
  try {
    return cvToString(deserializeCV(r.Ok));
  } catch {
    return r.Ok;
  }
}

function assert(label, actual, ok) {
  checks += 1;
  if (ok) {
    console.log(`  ok   ${label}: ${String(actual).slice(0, 110)}`);
  } else {
    failures += 1;
    console.log(`  FAIL ${label}: ${String(actual).slice(0, 200)}`);
  }
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
    // A leg is healthy when it returns (ok ...). Anything else - an (err ...),
    // an allowance abort, a runtime error - is a real failure worth seeing.
    assert(step.label, v, String(v).startsWith("(ok"));
  }
});

console.log(`\n${checks - failures}/${checks} checks green`);
if (failures > 0) process.exit(1);

// 53/53 green 2026-08-26 https://stxer.xyz/simulations/mainnet/ae88a0bad4377b86d49ae45b224fc051
