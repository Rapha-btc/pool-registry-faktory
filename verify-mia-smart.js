// verify-mia-smart.js
// Self-verifying stxer mainnet-fork harness for mia-smart-faktory.
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
// Run: node verify-mia-smart.js
import fs from "node:fs";
import {
  uintCV,
  boolCV,
  ClarityVersion,
  cvToString,
  deserializeCV,
} from "@stacks/transactions";
import { SimulationBuilder, getSimulationResult } from "stxer";

const DEPLOYER = "SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM";
const C = `${DEPLOYER}.mia-smart-faktory`;

// Funded mainnet principals, impersonated by the fork.
const SBTC_HOLDER = "SP2C7BCAP2NH3EYWCCVHJ6K0DMZBXDFKQ56KR7QN2"; // ~40 BTC
const STX_HOLDER = "SP9BP4PN74CNR5XT7CMAMBPA0GWC9HMB69HVVV51";
const MIA_HOLDER = "SP3HXJJMJQ06GNAZ8XWDN1QM48JEDC6PP6W3YZPZJ"; // 1.64B MIA

const SBTC_AMOUNT = 100000n; // 100k sats
const STX_AMOUNT = 100000000n; // 100 STX (6dec)
const MIA_AMOUNT = 100000000n; // 100 MIA (6dec)

// 0 and 100 are the single-venue extremes; 50 exercises the split path where
// both legs run and the allowances have to hold for each.
const RATIOS = [0n, 50n, 100n];

const src = fs.readFileSync("./contracts/mia-smart-faktory.clar", "utf8");

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
    contract_name: "mia-smart-faktory",
    source_code: src,
    // Clarity 5: as-contract? with with-ft / with-stx allowances.
    clarity_version: ClarityVersion.Clarity5,
  });
steps.push({ label: "deploy mia-smart-faktory (Clarity 5)", kind: "deploy" });

// --- read-only surface -------------------------------------------------------
for (const [label, code] of [
  ["fak sbtc/token liquidity", "(get-fak-sbtc-token-liquidity)"],
  ["alex stx/token liquidity", "(get-alex-stx-token-liquidity)"],
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

// --- dedicated DLMM bridge path (ratio=50 split; v-2 liquid pool, one v-1) ---
b.withSender(SBTC_HOLDER).addContractCall({
  contract_id: C,
  function_name: "buy-with-sbtc-dlmm",
  function_args: [uintCV(SBTC_AMOUNT), uintCV(1), uintCV(50n), uintCV(2n)],
});
expectOk("buy-with-sbtc-dlmm ratio=50 pool=v2");
b.withSender(STX_HOLDER).addContractCall({
  contract_id: C,
  function_name: "buy-with-stx-dlmm",
  function_args: [uintCV(STX_AMOUNT), uintCV(1), uintCV(50n), uintCV(2n)],
});
expectOk("buy-with-stx-dlmm ratio=50 pool=v2");
b.withSender(MIA_HOLDER).addContractCall({
  contract_id: C,
  function_name: "sell-for-sbtc-dlmm",
  function_args: [uintCV(MIA_AMOUNT), uintCV(1), uintCV(50n), uintCV(2n)],
});
expectOk("sell-for-sbtc-dlmm ratio=50 pool=v2");
b.withSender(MIA_HOLDER).addContractCall({
  contract_id: C,
  function_name: "sell-for-stx-dlmm",
  function_args: [uintCV(MIA_AMOUNT), uintCV(1), uintCV(50n), uintCV(2n)],
});
expectOk("sell-for-stx-dlmm ratio=50 pool=v2");
// prove the 3-pool selector reaches v-1 (legacy TVL) too
b.withSender(SBTC_HOLDER).addContractCall({
  contract_id: C,
  function_name: "buy-with-sbtc-dlmm",
  function_args: [uintCV(SBTC_AMOUNT), uintCV(1), uintCV(50n), uintCV(1n)],
});
expectOk("buy-with-sbtc-dlmm ratio=50 pool=v1");

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
  } else {
    const v = decodeTx(s);
    // A leg is healthy when it returns (ok ...). Anything else - an (err ...),
    // an allowance abort, a runtime error - is a real failure worth seeing.
    assert(step.label, v, String(v).startsWith("(ok"));
  }
});

console.log(`\n${checks - failures}/${checks} checks green`);
if (failures > 0) process.exit(1);
