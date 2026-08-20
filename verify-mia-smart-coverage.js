// verify-mia-smart-coverage.js
// Invariant + edge coverage for mia-smart-faktory, beyond the "(ok ...)" checks
// in verify-mia-smart.js. Deploys fresh and asserts:
//   S1 buy conservation + payout: user MIA delta == returned total-token-out,
//      and the contract holds 0 MIA/sBTC/STX afterwards (no leak).
//   S2 sell conservation + payout: user sBTC delta == returned total-sbtc-out.
//   S3 DLMM ratio extremes: ratio=100 (all Faktory, no bridge) on all four
//      *-dlmm functions, plus a small-amount ratio=0 (full DLMM bridge) that
//      fits the v2 bins.
//   S4 DLMM negatives: ratio=101 -> ERR-INVALID-RATIO, huge min-out -> ERR-SLIPPAGE.
//   S5 ERR-PARTIAL-FILL: a 20k-sat sBTC->STX bridge on the thin v-3 pool
//      (~20 STX) can't fill, so the (is-eq in amount) guard reverts u1003 and
//      the contract holds 0 afterwards -- funds protected, never stranded.
//   S6 3-pool dispatch: a 2k-sat bridge fits v-3 -> ok, proving the dlmm-pool
//      selector reaches all three versions (v1 covered in verify-mia-smart.js).
//
// Block advances between groups give each a fresh execution-cost budget (DLMM
// bin-walks are compute-heavy; without this the sim overflows the per-block cap).
//
// Run: node verify-mia-smart-coverage.js
import fs from "node:fs";
import { uintCV, boolCV, ClarityVersion, cvToString, deserializeCV } from "@stacks/transactions";
import { SimulationBuilder, getSimulationResult } from "stxer";

const DEPLOYER = "SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM";
const C = `${DEPLOYER}.mia-smart-faktory`;
const SBTC_HOLDER = "SP2C7BCAP2NH3EYWCCVHJ6K0DMZBXDFKQ56KR7QN2";
const STX_HOLDER = "SP9BP4PN74CNR5XT7CMAMBPA0GWC9HMB69HVVV51";
const MIA_HOLDER = "SP3HXJJMJQ06GNAZ8XWDN1QM48JEDC6PP6W3YZPZJ";

const MIA = "SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token-v2";
const SBTC = "SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token";

const SBTC_AMOUNT = 100000n;
const SBTC_SMALL = 3000n; // fits the thin v2 DLMM bins on a full sBTC->STX bridge
const STX_AMOUNT = 100000000n;
const MIA_AMOUNT = 100000000n;

const plan = [];
const src = fs.readFileSync("./contracts/mia-smart-faktory.clar", "utf8");
const b = SimulationBuilder.new().withSender(DEPLOYER).addContractDeploy({
  contract_name: "mia-smart-faktory",
  source_code: src,
  clarity_version: ClarityVersion.Clarity5,
});
plan.push({ kind: "tx", label: "deploy mia-smart-faktory (Clarity 5)", expect: /^\(ok / });

function call(label, sender, fn, args, expect, capture) {
  b.withSender(sender).addContractCall({ contract_id: C, function_name: fn, function_args: args });
  plan.push({ kind: "tx", label, expect, capture });
}
function evalc(label, code, capture) {
  b.addEvalCode(C, code);
  plan.push({ kind: "eval", label, capture });
}
function advance() {
  b.addAdvanceBlocks({ bitcoin_blocks: 1, stacks_blocks_per_bitcoin: 1, bitcoin_interval_secs: 1 });
  plan.push({ kind: "advance" });
}
const bal = (tok, who) => `(contract-call? '${tok} get-balance '${who})`;

// ---- S1: buy conservation + payout ----
evalc("S1 user MIA before", bal(MIA, SBTC_HOLDER), "s1MiaBefore");
call("S1 buy-with-sbtc ratio=50 bitflow -> ok", SBTC_HOLDER, "buy-with-sbtc",
  [uintCV(SBTC_AMOUNT), uintCV(1), uintCV(50n), boolCV(true)], /^\(ok /, "s1Buy");
evalc("S1 user MIA after", bal(MIA, SBTC_HOLDER), "s1MiaAfter");
evalc("S1 contract MIA (expect 0)", bal(MIA, C), "s1cMia");
evalc("S1 contract sBTC (expect 0)", bal(SBTC, C), "s1cSbtc");
evalc("S1 contract STX (expect 0)", `(stx-get-balance '${C})`, "s1cStx");
advance();

// ---- S2: sell conservation + payout ----
evalc("S2 user sBTC before", bal(SBTC, MIA_HOLDER), "s2SbtcBefore");
call("S2 sell-for-sbtc ratio=50 velar -> ok", MIA_HOLDER, "sell-for-sbtc",
  [uintCV(MIA_AMOUNT), uintCV(1), uintCV(50n), boolCV(false)], /^\(ok /, "s2Sell");
evalc("S2 user sBTC after", bal(SBTC, MIA_HOLDER), "s2SbtcAfter");
evalc("S2 contract MIA (expect 0)", bal(MIA, C), "s2cMia");
evalc("S2 contract sBTC (expect 0)", bal(SBTC, C), "s2cSbtc");
advance();

// ---- S3a: ratio=100 (all Faktory, no bridge) on all four DLMM functions ----
call("S3 buy-with-sbtc-dlmm ratio=100 pool=v2 -> ok", SBTC_HOLDER, "buy-with-sbtc-dlmm",
  [uintCV(SBTC_AMOUNT), uintCV(1), uintCV(100n), uintCV(2n)], /^\(ok /);
call("S3 buy-with-stx-dlmm ratio=100 pool=v2 -> ok", STX_HOLDER, "buy-with-stx-dlmm",
  [uintCV(STX_AMOUNT), uintCV(1), uintCV(100n), uintCV(2n)], /^\(ok /);
call("S3 sell-for-sbtc-dlmm ratio=100 pool=v2 -> ok", MIA_HOLDER, "sell-for-sbtc-dlmm",
  [uintCV(MIA_AMOUNT), uintCV(1), uintCV(100n), uintCV(2n)], /^\(ok /);
call("S3 sell-for-stx-dlmm ratio=100 pool=v2 -> ok", MIA_HOLDER, "sell-for-stx-dlmm",
  [uintCV(MIA_AMOUNT), uintCV(1), uintCV(100n), uintCV(2n)], /^\(ok /);
advance();

// ---- S3b: ratio=0 (full DLMM bridge) sized to fit the v2 bins ----
call("S3 buy-with-sbtc-dlmm small ratio=0 pool=v2 -> ok", SBTC_HOLDER, "buy-with-sbtc-dlmm",
  [uintCV(SBTC_SMALL), uintCV(1), uintCV(0n), uintCV(2n)], /^\(ok /);
call("S3 buy-with-stx-dlmm ratio=0 pool=v2 -> ok", STX_HOLDER, "buy-with-stx-dlmm",
  [uintCV(STX_AMOUNT), uintCV(1), uintCV(0n), uintCV(2n)], /^\(ok /);
call("S3 sell-for-sbtc-dlmm ratio=0 pool=v2 -> ok", MIA_HOLDER, "sell-for-sbtc-dlmm",
  [uintCV(MIA_AMOUNT), uintCV(1), uintCV(0n), uintCV(2n)], /^\(ok /);
call("S3 sell-for-stx-dlmm ratio=0 pool=v2 -> ok", MIA_HOLDER, "sell-for-stx-dlmm",
  [uintCV(MIA_AMOUNT), uintCV(1), uintCV(0n), uintCV(2n)], /^\(ok /);
evalc("S3 contract MIA after extremes (expect 0)", bal(MIA, C), "s3cMia");
evalc("S3 contract sBTC after extremes (expect 0)", bal(SBTC, C), "s3cSbtc");
evalc("S3 contract STX after extremes (expect 0)", `(stx-get-balance '${C})`, "s3cStx");
advance();

// ---- S4: DLMM negatives ----
call("S4 buy-with-sbtc-dlmm ratio=101 -> ERR-INVALID-RATIO", SBTC_HOLDER, "buy-with-sbtc-dlmm",
  [uintCV(SBTC_AMOUNT), uintCV(1), uintCV(101n), uintCV(2n)], "(err u1002)");
call("S4 sell-for-stx-dlmm ratio=101 -> ERR-INVALID-RATIO", MIA_HOLDER, "sell-for-stx-dlmm",
  [uintCV(MIA_AMOUNT), uintCV(1), uintCV(101n), uintCV(2n)], "(err u1002)");
call("S4 buy-with-sbtc-dlmm huge min-out -> ERR-SLIPPAGE", SBTC_HOLDER, "buy-with-sbtc-dlmm",
  [uintCV(SBTC_SMALL), uintCV(1000000000000000n), uintCV(0n), uintCV(2n)], "(err u1000)");
advance();

// ---- S5: ERR-PARTIAL-FILL on the thin v-3 pool (holds only ~20 STX). A
//         20k-sat sBTC->STX bridge needs ~100 STX out -> router fills partial
//         -> the (is-eq in amount) guard reverts u1003, protecting funds. ----
call("S5 buy-with-sbtc-dlmm 20k ratio=0 pool=v3 -> ERR-PARTIAL-FILL", SBTC_HOLDER, "buy-with-sbtc-dlmm",
  [uintCV(20000n), uintCV(1), uintCV(0n), uintCV(3n)], "(err u1003)");
evalc("S5 contract sBTC after partial-fill revert (expect 0)", bal(SBTC, C), "s5cSbtc");
advance();

// ---- S6: 3-pool selector reaches v-3 too. A tiny 2k-sat bridge (~10 STX)
//         fits v-3's 20 STX -> ok, proving dispatch to all three versions. ----
call("S6 buy-with-sbtc-dlmm 2k ratio=0 pool=v3 -> ok", SBTC_HOLDER, "buy-with-sbtc-dlmm",
  [uintCV(2000n), uintCV(1), uintCV(0n), uintCV(3n)], /^\(ok /);
evalc("S6 contract sBTC after v3 buy (expect 0)", bal(SBTC, C), "s6cSbtc");

// ============ run + assert ============
function decodeTx(s) {
  const r = s?.Result?.Transaction;
  if (!r) return "<no tx>";
  if ("Err" in r) return `ENGINE-ERR ${JSON.stringify(r.Err).slice(0, 120)}`;
  try { return cvToString(deserializeCV(r.Ok.result)); } catch { return `raw:${r.Ok?.result}`; }
}
function decodeEval(s) {
  const r = s?.Result?.Eval;
  if (!r) return "<no eval>";
  if (!("Ok" in r)) return `ERR ${JSON.stringify(r.Err).slice(0, 120)}`;
  try { return cvToString(deserializeCV(r.Ok)); } catch { return String(r.Ok); }
}
const num = (s, key) => BigInt((String(s).match(new RegExp(`\\(${key} u(\\d+)\\)`)) || [])[1] ?? "-1");
const bare = (s) => BigInt((String(s).match(/u(\d+)/) || [])[1] ?? "-1");

const sid = await b.run();
const url = `https://stxer.xyz/simulations/mainnet/${sid}`;
console.log(`\nView: ${url}\n`);
const res = await getSimulationResult(sid);
const cap = {};
let pass = 0, fail = 0;
const check = (label, ok, got) => {
  ok ? pass++ : fail++;
  console.log(`  ${ok ? "ok  " : "FAIL"} ${label}${ok ? "" : `  got ${got}`}`);
};

res.steps.forEach((s, i) => {
  const p = plan[i];
  if (!p || p.kind === "advance") return;
  if (p.kind === "eval") {
    const v = decodeEval(s);
    if (p.capture) cap[p.capture] = v;
  } else {
    const v = decodeTx(s);
    if (p.capture) cap[p.capture] = v;
    const ok = p.expect instanceof RegExp ? p.expect.test(v) : v === p.expect;
    check(`${p.label}`, ok, v);
  }
});

check("S1 user MIA delta == returned total-token-out",
  bare(cap.s1MiaAfter) - bare(cap.s1MiaBefore) === num(cap.s1Buy, "total-token-out"),
  `${bare(cap.s1MiaAfter) - bare(cap.s1MiaBefore)} vs ${num(cap.s1Buy, "total-token-out")}`);
check("S1 contract holds 0 MIA", bare(cap.s1cMia) === 0n, cap.s1cMia);
check("S1 contract holds 0 sBTC", bare(cap.s1cSbtc) === 0n, cap.s1cSbtc);
check("S1 contract holds 0 STX", bare(cap.s1cStx) === 0n, cap.s1cStx);

check("S2 user sBTC delta == returned total-sbtc-out",
  bare(cap.s2SbtcAfter) - bare(cap.s2SbtcBefore) === num(cap.s2Sell, "total-sbtc-out"),
  `${bare(cap.s2SbtcAfter) - bare(cap.s2SbtcBefore)} vs ${num(cap.s2Sell, "total-sbtc-out")}`);
check("S2 contract holds 0 MIA", bare(cap.s2cMia) === 0n, cap.s2cMia);
check("S2 contract holds 0 sBTC", bare(cap.s2cSbtc) === 0n, cap.s2cSbtc);

check("S3 contract holds 0 MIA after extremes", bare(cap.s3cMia) === 0n, cap.s3cMia);
check("S3 contract holds 0 sBTC after extremes", bare(cap.s3cSbtc) === 0n, cap.s3cSbtc);
check("S3 contract holds 0 STX after extremes", bare(cap.s3cStx) === 0n, cap.s3cStx);
check("S5 contract holds 0 sBTC after partial-fill revert", bare(cap.s5cSbtc) === 0n, cap.s5cSbtc);
check("S6 contract holds 0 sBTC after v3 buy", bare(cap.s6cSbtc) === 0n, cap.s6cSbtc);

console.log(`\n=== ${pass} passed, ${fail} failed ===`);
console.log(`View: ${url}`);
if (fail > 0) process.exit(1);
