// verify-mia-arbitrage.cjs
// SELF-VERIFYING stxer mainnet-fork sim for the DRAFT contract
// contracts/mia-arbitrage-faktory.clar (not yet deployed).
//
//   Act 0  deploy the draft under SPV9K21 + opcode sanity on mia-pool quote
//   Act 1  whale pumps fak (200k sats buy) -> fak rich vs ALEX
//   Act 2  check-fak-bit-alex(100k MIA) eval, then arb-fak-bit-alex -> ok,
//          profit > 0, actual within 1% of the check estimate
//   Act 3  pump again, same for the velar bridge: arb-fak-vel-alex
//   Act 4  whale dumps 1M MIA on fak -> fak cheap vs ALEX; reverse routes:
//          arb-alex-bit-fak then arb-alex-vel-fak (both checked vs estimates)
//   Act 5  guards: wrong-direction arb -> err u1001; stranger rescue -> u1002;
//          deployer rescue -> ok; no dust stranded in the arb contract;
//          deployer MIA delta == sum of arb outputs + rescued amount
//
// Run: NODE_PATH=/home/raphastacks/projects/mia-single-faktory/node_modules \
//      node simulations/verify-mia-arbitrage.cjs
const fs = require("fs");
const path = require("path");
const { uintCV, someCV, bufferCV, noneCV, standardPrincipalCV, contractPrincipalCV, deserializeCV, cvToString } = require("@stacks/transactions");
const { SimulationBuilder, getSimulationResult } = require("stxer");

const DEPLOYER = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22";
const WHALE = "SP2C7BCAP2NH3EYWCCVHJ6K0DMZBXDFKQ56KR7QN2"; // 40+ sBTC
const MIA_WHALE = "SP3HXJJMJQ06GNAZ8XWDN1QM48JEDC6PP6W3YZPZJ"; // 1.64B MIA
const STRANGER = "SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM";

const MIA = "SP1H1733V5MZ3SZ9XRW9FKYGEZT0JDGEB8Y634C7R.miamicoin-token-v2";
const SBTC = "SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token";
const CORE = `${DEPLOYER}.fakfun-core-v2`;
const POOL_CID = `${DEPLOYER}.mia-pool-faktory`;
const ARB_NAME = "mia-arbitrage-faktory";
const ARB_CID = `${DEPLOYER}.${ARB_NAME}`;

const SOURCE = fs.readFileSync(
  path.join(__dirname, "..", "contracts", `${ARB_NAME}.clar`),
  "utf8",
);

const PUMP_SATS = 200_000n;
const ARB_1 = 100_000_000_000n; // 100k MIA (6-dec)
const ARB_2 = 100_000_000_000n;
const DUMP_MIA = 8_000_000_000_000n; // 8M MIA (MIA whale) -> fak far below ALEX
const ARB_3 = 100_000_000_000n;
const ARB_4 = 50_000_000_000n; // 50k MIA
const ARB_DLMM = 25_000_000_000n; // 25k MIA (DLMM pool is thin)
const RESCUE_MIA = 1_000_000n; // 1 MIA

const plan = [];
const b = SimulationBuilder.new({ stacksNodeAPI: "http://77.42.3.101/stacks-api" });

function call(label, sender, cid, fn, args, expect, capture) {
  b.withSender(sender).addContractCall({ contract_id: cid, function_name: fn, function_args: args });
  plan.push({ kind: "tx", label, expect, capture });
}
function evalc(label, code, capture) {
  b.addEvalCode(POOL_CID, code);
  plan.push({ kind: "eval", label, capture });
}
const execArgs = (amount, opcode) => [
  contractPrincipalCV(DEPLOYER, "mia-pool-faktory"),
  uintCV(amount),
  someCV(bufferCV(Uint8Array.from([opcode]))),
];

// ---- Act 0: deploy + sanity ----
// Clarity 5: the contract uses current-contract + as-contract? allowances.
b.withSender(DEPLOYER).addContractDeploy({ contract_name: ARB_NAME, source_code: SOURCE, clarity_version: 5 });
plan.push({ kind: "tx", label: "deploy mia-arbitrage-faktory", expect: /^\(ok / });

evalc("deployer MIA before all", `(contract-call? '${MIA} get-balance '${DEPLOYER})`, "depMia0");
evalc("fak reserves baseline", `(contract-call? '${POOL_CID} get-reserves-quote)`, "res0");
evalc("opcode 0x01 = MIA->sBTC (1M MIA -> ~2e5 sats)",
  `(get dy (unwrap-panic (contract-call? '${POOL_CID} quote u1000000000000 (some 0x01))))`, "op01");
evalc("opcode 0x00 = sBTC->MIA (100k sats -> ~5e11 uMIA)",
  `(get dy (unwrap-panic (contract-call? '${POOL_CID} quote u100000 (some 0x00))))`, "op00");

// ---- Act 1: pump fak ----
call("whale pumps fak: buy MIA w/ 200k sats -> ok", WHALE,
  CORE, "execute", execArgs(PUMP_SATS, 0x00), /^\(ok /);
evalc("fak reserves after pump", `(contract-call? '${POOL_CID} get-reserves-quote)`, "res1");

// ---- Act 2: forward route, bitflow bridge ----
evalc("check-fak-bit-alex(100k MIA)",
  `(contract-call? '${ARB_CID} check-fak-bit-alex u${ARB_1})`, "chk1");
call("arb-fak-bit-alex(100k MIA) -> ok", WHALE,
  ARB_CID, "arb-fak-bit-alex", [uintCV(ARB_1), uintCV(0n)], /^\(ok /, "arb1");

// ---- Act 3: pump again, forward route, velar bridge ----
call("whale pumps fak again (200k sats) -> ok", WHALE,
  CORE, "execute", execArgs(PUMP_SATS, 0x00), /^\(ok /);
evalc("check-fak-vel-alex(100k MIA)",
  `(contract-call? '${ARB_CID} check-fak-vel-alex u${ARB_2})`, "chk2");
call("arb-fak-vel-alex(100k MIA) -> ok", WHALE,
  ARB_CID, "arb-fak-vel-alex", [uintCV(ARB_2), uintCV(0n)], /^\(ok /, "arb2");

// ---- Act 3b: DLMM bridge, forward (no on-chain check; profit-or-revert) ----
call("whale pumps fak a third time (200k sats) -> ok", WHALE,
  CORE, "execute", execArgs(PUMP_SATS, 0x00), /^\(ok /);
call("arb-fak-dlmm-alex(25k MIA, pool v2) -> ok", WHALE,
  ARB_CID, "arb-fak-dlmm-alex", [uintCV(ARB_DLMM), uintCV(0n), uintCV(2n)], /^\(ok /, "arb5");

// ---- Act 4: dump fak, reverse routes ----
call("MIA whale dumps 8M MIA on fak -> ok", MIA_WHALE,
  CORE, "execute", execArgs(DUMP_MIA, 0x01), /^\(ok /);
evalc("fak reserves after dump", `(contract-call? '${POOL_CID} get-reserves-quote)`, "res2");

evalc("check-alex-bit-fak(100k MIA)",
  `(contract-call? '${ARB_CID} check-alex-bit-fak u${ARB_3})`, "chk3");
call("arb-alex-bit-fak(100k MIA) -> ok", WHALE,
  ARB_CID, "arb-alex-bit-fak", [uintCV(ARB_3), uintCV(0n)], /^\(ok /, "arb3");

evalc("check-alex-vel-fak(50k MIA)",
  `(contract-call? '${ARB_CID} check-alex-vel-fak u${ARB_4})`, "chk4");
call("arb-alex-vel-fak(50k MIA) -> ok", WHALE,
  ARB_CID, "arb-alex-vel-fak", [uintCV(ARB_4), uintCV(0n)], /^\(ok /, "arb4");

call("arb-alex-dlmm-fak(25k MIA, pool v1 legacy) -> ok", WHALE,
  ARB_CID, "arb-alex-dlmm-fak", [uintCV(ARB_DLMM), uintCV(0n), uintCV(1n)], /^\(ok /, "arb6");
call("arb-alex-dlmm-fak(25k MIA, pool v3 EMPTY) -> err", WHALE,
  ARB_CID, "arb-alex-dlmm-fak", [uintCV(ARB_DLMM), uintCV(0n), uintCV(3n)], /^\(err /);

// ---- Act 5: guards ----
call("wrong direction (fak cheap): arb-fak-bit-alex -> err u1001", WHALE,
  ARB_CID, "arb-fak-bit-alex", [uintCV(10_000_000_000n), uintCV(0n)], "(err u1001)");

call("whale sends 1 MIA to arb contract (rescue fixture)", WHALE,
  MIA, "transfer",
  [uintCV(RESCUE_MIA), standardPrincipalCV(WHALE), contractPrincipalCV(DEPLOYER, ARB_NAME), noneCV()],
  /^\(ok /);
call("stranger rescue-token -> err u1002", STRANGER,
  ARB_CID, "rescue-token", [uintCV(RESCUE_MIA)], "(err u1002)");
call("deployer rescue-token -> ok", DEPLOYER,
  ARB_CID, "rescue-token", [uintCV(RESCUE_MIA)], /^\(ok /);

evalc("arb contract MIA left (expect 0)", `(contract-call? '${MIA} get-balance '${ARB_CID})`, "arbMia");
evalc("arb contract sBTC left (expect 0)", `(contract-call? '${SBTC} get-balance '${ARB_CID})`, "arbSbtc");
evalc("arb contract STX left (expect 0)", `(stx-get-balance '${ARB_CID})`, "arbStx");
evalc("deployer MIA after all", `(contract-call? '${MIA} get-balance '${DEPLOYER})`, "depMia1");

// ============ run + assert ============
function decodeTx(s) {
  const r = s?.Result?.Transaction;
  if (!r) return { ok: false, str: "<no transaction result>" };
  if ("Err" in r) return { ok: false, str: `ENGINE-ERR: ${JSON.stringify(r.Err).slice(0, 200)}` };
  try { return { ok: true, str: cvToString(deserializeCV(r.Ok.result)) }; }
  catch (e) { return { ok: false, str: `decode-failed(${r.Ok.result}): ${e.message}` }; }
}
function decodeEval(s) {
  const r = s?.Result?.Eval;
  if (!r) return "<no eval result>";
  if (!("Ok" in r)) return `ERR: ${JSON.stringify(r.Err).slice(0, 200)}`;
  try { return cvToString(deserializeCV(r.Ok)); } catch { return r.Ok; }
}
const num = (s, key) => BigInt((String(s).match(new RegExp(`\\(${key} u(\\d+)\\)`)) || [])[1] ?? "-1");
const bare = (s) => BigInt((String(s).match(/u(\d+)/) || [])[1] ?? "-1");

async function main() {
  console.log("=== mia-arbitrage-faktory draft: all 4 routes + guards -- live-state sim ===\n");
  const sessionId = await b.run();
  const url = `https://stxer.xyz/simulations/mainnet/${sessionId}`;
  console.log(`Submitted. Fetching results...\n${url}\n`);
  const res = await getSimulationResult(sessionId);
  const captured = {};
  let pass = 0, fail = 0;

  res.steps.forEach((s, i) => {
    const p = plan[i];
    if (!p) return;
    if (p.kind === "tx") {
      const d = decodeTx(s);
      if (p.capture) captured[p.capture] = d.str;
      const ok = p.expect instanceof RegExp ? p.expect.test(d.str) : d.str === p.expect;
      console.log(`${ok ? "✅" : "❌"} [${i}] ${p.label}\n        got ${d.str.slice(0, 160)}${ok ? "" : `\n        EXPECTED ${p.expect}`}`);
      ok ? pass++ : fail++;
    } else if (p.kind === "eval") {
      const v = decodeEval(s);
      if (p.capture) captured[p.capture] = v;
      console.log(`ℹ️  [${i}] ${p.label}: ${String(v).slice(0, 180)}`);
    }
  });

  console.log("\n--- numeric cross-checks ---");
  const check = (label, got, want) => {
    const ok = got === want;
    console.log(`${ok ? "✅" : "❌"} ${label}: ${got}${ok ? "" : ` (want ${want})`}`);
    ok ? pass++ : fail++;
  };
  const inRange = (label, got, lo, hi) => {
    const ok = got >= lo && got <= hi;
    console.log(`${ok ? "✅" : "❌"} ${label}: ${got}${ok ? "" : ` (want ${lo}..${hi})`}`);
    ok ? pass++ : fail++;
  };
  // |actual - est| <= est/100 (1%) — validates the x100 decimal conversions:
  // any decimal slip would be off by 100x, not 1%.
  const closeTo = (label, actual, est) => {
    const diff = actual > est ? actual - est : est - actual;
    const ok = est > 0n && diff <= est / 100n;
    console.log(`${ok ? "✅" : "❌"} ${label}: actual ${actual} vs est ${est} (diff ${diff})`);
    ok ? pass++ : fail++;
  };

  // opcode sanity: 1M MIA -> sats (fak mid ~207k/1M); 100k sats -> uMIA
  inRange("quote 0x01: 1M MIA -> sats", bare(captured.op01), 100_000n, 400_000n);
  inRange("quote 0x00: 100k sats -> uMIA", bare(captured.op00), 200_000_000_000n, 800_000_000_000n);

  const arbs = [
    ["route 1 fak-bit-alex", "arb1", "chk1", ARB_1],
    ["route 2 fak-vel-alex", "arb2", "chk2", ARB_2],
    ["route 3 alex-bit-fak", "arb3", "chk3", ARB_3],
    ["route 4 alex-vel-fak", "arb4", "chk4", ARB_4],
  ];
  // DLMM routes have no read-only estimate (bin walk): profit-or-revert only
  for (const [label, key, amtIn] of [["route 5 fak-dlmm-alex","arb5",ARB_DLMM],["route 6 alex-dlmm-fak","arb6",ARB_DLMM]]) {
    const out = num(captured[key], "token-out");
    inRange(`${label}: profit (out - in)`, out - amtIn, 1n, amtIn * 10n);
  }
  let sumOut = 0n;
  for (const [label, arbKey, chkKey, amtIn] of arbs) {
    const actualOut = num(captured[arbKey], "token-out");
    const estOut = num(captured[chkKey], "amt-out");
    const estProfitable = String(captured[chkKey]).includes("(profitable true)");
    sumOut += actualOut;
    check(`${label}: check said profitable`, estProfitable, true);
    // >0 and sane (the forced dump makes reverse routes multi-x profitable)
    inRange(`${label}: profit (out - in)`, actualOut - amtIn, 1n, amtIn * 10n);
    closeTo(`${label}: actual vs estimate`, actualOut, estOut);
  }

  check("no MIA stranded in arb contract", bare(captured.arbMia), 0n);
  check("no sBTC stranded in arb contract", bare(captured.arbSbtc), 0n);
  check("no STX stranded in arb contract", bare(captured.arbStx), 0n);
  const dlmmOut = num(captured.arb5, "token-out") + num(captured.arb6, "token-out");
  check("deployer received every arb output + rescue",
    bare(captured.depMia1) - bare(captured.depMia0), sumOut + dlmmOut + RESCUE_MIA);

  console.log(`\n=== ${pass} passed, ${fail} failed ===`);
  console.log(`View: ${url}`);
  if (fail > 0) process.exit(1);
}

main().catch((err) => { console.error(err); process.exit(1); });
