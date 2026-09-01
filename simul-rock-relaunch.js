// simul-rock-relaunch.js
// SELF-VERIFYING stxer mainnet-fork sim for the ROCK relaunch pattern:
// gated pool (rock-faktory-pool-3) + pepe-style single-sided
// (rock-single-faktory) with a 1B ROCK seed from the depositor.
//
// The arc, against REAL mainnet state (real ROCK whale, real sBTC holders):
//   1. deploy pool-3 + single under SPV9K21 (Clarity5 in the sim - stxer
//      0.8.0 caps there; sources only use C5 constructs, same as the MIA sims)
//   2. fund the deployer: ROCK from the whale, sats from depositor 1
//   3. pool.initialize-pool at pool-2's live ratio (~6,317 uROCK/sat),
//      swaps stay GATED
//   4. deposit before single is initialized -> err u404
//   5. HIGHROLLER (whale) seeds the single with 1,000,000,000 ROCK (1e15)
//   6. guards: gated swap u403 (direct call blocked), dust lp u406,
//      depositor self-deposit u403, early withdraw u407, early sweep u407
//   7. two community sBTC deposits pair at the frozen ratio (exact amounts)
//   8. go button: set-gated false -> swaps both ways, 0.1% faktory fee lands
//   9. advance ~3 weeks: deposits now u409 TOO_LATE; depositor sweeps the
//      EXACT unused ROCK (1e15 - token-used)
//  10. advance to ~90d: dep1 self-withdraw + depositor pushes dep2 out;
//      both sides split 60/40 user/depositor; single ends holding NOTHING
//
// Run: node simul-rock-relaunch.js
import fs from "node:fs";
import {
  ClarityVersion,
  uintCV,
  boolCV,
  noneCV,
  standardPrincipalCV,
  deserializeCV,
  cvToString,
} from "@stacks/transactions";
import { SimulationBuilder, getSimulationResult } from "stxer";

// --- Mainnet actors (impersonated on the fork; balances verified 2026-09-01) ---
const DEPLOYER = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22";
const HIGHROLLER = "SP1J9JVDWMAM63RZM54R43TK84XCT85C2W254TMYX"; // 3.2B ROCK
const DEP1 = "SP2C7BCAP2NH3EYWCCVHJ6K0DMZBXDFKQ56KR7QN2"; // 40.8 sBTC
const DEP2 = "SP22WH53NS94VR6N145ZX77BK4S0EWFBE41VW3Z6B"; // 0.10 sBTC
const STRANGER = "SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM";

const ROCK = "SP4M2C88EE8RQZPYTC4PZ88CE16YGP825EYF6KBQ.stacks-rock";
const SBTC = "SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token";
const FAKTORY_FEE_ADDR = "SMH8FRN30ERW1SX26NJTJCKTDR3H27NRJ6W75WQE";

const POOL_CID = `${DEPLOYER}.rock-faktory-pool-3`;
const SINGLE_CID = `${DEPLOYER}.rock-single-faktory`;

// --- Pool seed at pool-2's live ratio (67,713 sats / 427.7M ROCK ->
//     6,317,000,000 uROCK per sat, rounded to keep expectations exact) ---
const RATIO = 6_317_000_000n; // uROCK per sat
const POOL_LOWEST = 100_000n; // first add: 100,000 sats (dx=dy=dk=100,000)
const POOL_HIGHEST = RATIO * POOL_LOWEST - POOL_LOWEST; // ROCK top-up -> dy exact
const SEED_ROCK = POOL_LOWEST + POOL_HIGHEST; // total ROCK the deployer needs
const SEED_SATS = POOL_LOWEST;

// --- The single-sided seed: 1B ROCK (6 decimals) ---
const VAULT_SEED = 1_000_000_000_000_000n; // 1e15 micro = 1,000,000,000 ROCK

// deposits (lp-denominated; pool starts at dk = 100,000)
const DEP1_LP = 100_000n; // -> 100,000 sats + 631.7e12 uROCK
const DEP2_LP = 10_000n; //  ->  10,000 sats +  63.17e12 uROCK
const DEP1_TOKEN = RATIO * DEP1_LP;
const DEP2_TOKEN = RATIO * DEP2_LP;
const TOKEN_USED = DEP1_TOKEN + DEP2_TOKEN;
const SWEEP_EXPECTED = VAULT_SEED - TOKEN_USED;

const rockBal = (a) => `(contract-call? '${ROCK} get-balance '${a})`;
const sbtcBal = (a) => `(contract-call? '${SBTC} get-balance '${a})`;

// ---- scenario builder with a parallel assertion plan ----
const plan = [];
const b = SimulationBuilder.new({ stacksNodeAPI: "http://77.42.3.101/stacks-api" });
const src = (n) => fs.readFileSync(`./contracts/${process.env.DEPLOY_VARIANT ? "d-" : ""}${n}.clar`, "utf8");

function deploy(name) {
  b.withSender(DEPLOYER).addContractDeploy({
    contract_name: name,
    source_code: src(name),
    clarity_version: ClarityVersion.Clarity5, // stxer max; sources are C5-compatible
  });
  plan.push({ kind: "deploy", label: `deploy ${name}` });
}
function call(label, sender, cid, fn, args, expect, capture) {
  b.withSender(sender).addContractCall({ contract_id: cid, function_name: fn, function_args: args });
  plan.push({ kind: "tx", label, expect, capture });
}
function evalc(label, code, capture) {
  b.addEvalCode(POOL_CID, code);
  plan.push({ kind: "eval", label, capture });
}
function advance(n) {
  b.addAdvanceBlocks({ bitcoin_blocks: n, stacks_blocks_per_bitcoin: 1, bitcoin_interval_secs: 1 });
  plan.push({ kind: "advance", label: `advance ${n} burn blocks` });
}

// =====================================================================
// Act 1 -- deploy + fund the deployer
// =====================================================================
deploy("rock-faktory-pool-3");
deploy("rock-single-faktory");

call("whale funds deployer with pool-seed ROCK", HIGHROLLER, ROCK, "transfer",
  [uintCV(SEED_ROCK), standardPrincipalCV(HIGHROLLER), standardPrincipalCV(DEPLOYER), noneCV()],
  "(ok true)");
call("dep1 funds deployer with 100k sats", DEP1, SBTC, "transfer",
  [uintCV(SEED_SATS), standardPrincipalCV(DEP1), standardPrincipalCV(DEPLOYER), noneCV()],
  "(ok true)");
// the ROCK whale holds zero sBTC; give him sats so the self-deposit guard
// test reaches the assert instead of dying in the sBTC transfer binding
call("dep1 funds whale with 20k sats (guard-test gas)", DEP1, SBTC, "transfer",
  [uintCV(20_000n), standardPrincipalCV(DEP1), standardPrincipalCV(HIGHROLLER), noneCV()],
  "(ok true)");

// =====================================================================
// Act 2 -- pool init at the honest ratio; swaps gated
// =====================================================================
call("stranger cannot initialize pool -> err u403", STRANGER, POOL_CID, "initialize-pool",
  [uintCV(POOL_LOWEST), uintCV(POOL_HIGHEST)], "(err u403)");
call("pool.initialize-pool (100k sats / 631.7M ROCK, gated)", DEPLOYER, POOL_CID,
  "initialize-pool", [uintCV(POOL_LOWEST), uintCV(POOL_HIGHEST)], "(ok true)");
evalc("pool reserves after init", `(contract-call? '${POOL_CID} get-reserves-quote)`, "reserves0");

// deposit before single is initialized aborts in the add-liquidity binding
// (vault holds no ROCK yet -> ft u1) before the u404 assert is reached
call("deposit before single init -> err", DEP1, SINGLE_CID, "deposit-sbtc-for-lp",
  [uintCV(DEP1_LP)], (s) => s.startsWith("(err"));

// =====================================================================
// Act 3 -- HIGHROLLER seeds the single with 1B ROCK
// =====================================================================
evalc("whale ROCK before seed", rockBal(HIGHROLLER), "hr_rock_before");
call("HIGHROLLER seeds single with 1B ROCK", HIGHROLLER, SINGLE_CID, "initialize-pool",
  [uintCV(VAULT_SEED)], "(ok true)");
call("second initialize -> err u405", HIGHROLLER, SINGLE_CID, "initialize-pool",
  [uintCV(1n)], "(err u405)");
evalc("vault ROCK after seed (1e15)", rockBal(SINGLE_CID), "vaultSeed");

// =====================================================================
// Act 4 -- guards while gated
// =====================================================================
call("gated direct swap -> err u403", DEP1, POOL_CID, "swap-a-to-b",
  [uintCV(10_000n), uintCV(0n)], "(err u403)");
call("dust deposit (lp=19) -> err u406", DEP1, SINGLE_CID, "deposit-sbtc-for-lp",
  [uintCV(19n)], "(err u406)");
call("depositor self-deposit -> err u403", HIGHROLLER, SINGLE_CID, "deposit-sbtc-for-lp",
  [uintCV(DEP2_LP)], "(err u403)");
call("early withdraw -> err u407 (lock gate fires first)", DEP1, SINGLE_CID, "withdraw-lp-tokens", [], "(err u407)");
call("early sweep -> err u407", HIGHROLLER, SINGLE_CID, "withdraw-remaining-token", [], "(err u407)");

// =====================================================================
// Act 5 -- community deposits at the frozen ratio
// =====================================================================
call("dep1: 100k-LP single-sided deposit", DEP1, SINGLE_CID, "deposit-sbtc-for-lp",
  [uintCV(DEP1_LP)], `(ok u${DEP1_LP})`);
call("dep2: 10k-LP single-sided deposit", DEP2, SINGLE_CID, "deposit-sbtc-for-lp",
  [uintCV(DEP2_LP)], `(ok u${DEP2_LP})`);
evalc("dep1 LP entitlement", `(contract-call? '${SINGLE_CID} get-user-lp-tokens '${DEP1})`, "dep1lp");
evalc("vault ROCK after deposits", rockBal(SINGLE_CID), "vaultAfterDeps");
evalc("single info after deposits", `(contract-call? '${SINGLE_CID} get-pool-info)`, "info1");
call("early withdraw with position -> err u407", DEP1, SINGLE_CID, "withdraw-lp-tokens", [], "(err u407)");

// =====================================================================
// Act 6 -- go button: open the gate, trade both ways
// =====================================================================
evalc("faktory fee addr sBTC before", sbtcBal(FAKTORY_FEE_ADDR), "fee_before");
call("stranger cannot open gate -> err u403", STRANGER, POOL_CID, "set-gated",
  [boolCV(false)], "(err u403)");
call("deployer opens the gate", DEPLOYER, POOL_CID, "set-gated",
  [boolCV(false)], "(ok true)");
call("buyer swaps 20k sats -> ROCK", DEP1, POOL_CID, "swap-a-to-b",
  [uintCV(20_000n), uintCV(0n)], /^\(ok \(tuple /, "buySwap");
call("whale sells 50M ROCK -> sBTC", HIGHROLLER, POOL_CID, "swap-b-to-a",
  [uintCV(50_000_000_000_000n), uintCV(0n)], /^\(ok \(tuple /, "sellSwap");
evalc("faktory fee addr sBTC after", sbtcBal(FAKTORY_FEE_ADDR), "fee_after");

// =====================================================================
// Act 7 -- ~3 weeks pass: entries close, depositor sweeps unused ROCK
// =====================================================================
advance(3_025);
call("deposit after entry window -> err u409", DEP1, SINGLE_CID, "deposit-sbtc-for-lp",
  [uintCV(1_000n)], "(err u409)");
call("stranger sweep -> err u403", STRANGER, SINGLE_CID, "withdraw-remaining-token", [], "(err u403)");
evalc("whale ROCK before sweep", rockBal(HIGHROLLER), "hr_rock_before_sweep");
call("depositor sweeps unused ROCK", HIGHROLLER, SINGLE_CID, "withdraw-remaining-token", [],
  `(ok u${SWEEP_EXPECTED})`);
evalc("whale ROCK after sweep", rockBal(HIGHROLLER), "hr_rock_after_sweep");
evalc("vault ROCK after sweep (0)", rockBal(SINGLE_CID), "vaultAfterSweep");
call("withdraw still locked at ~3w -> err u407", DEP1, SINGLE_CID, "withdraw-lp-tokens", [], "(err u407)");

// =====================================================================
// Act 8 -- ~90 days: withdrawals, 60/40 both sides, nothing stranded
// =====================================================================
advance(9_940);
call("stranger withdraw (no deposit) -> err u408", STRANGER, SINGLE_CID, "withdraw-lp-tokens", [], "(err u408)");
evalc("dep1 sBTC before withdraw", sbtcBal(DEP1), "d1_sbtc_before");
evalc("dep1 ROCK before withdraw", rockBal(DEP1), "d1_rock_before");
evalc("dep2 sBTC before withdrawals", sbtcBal(DEP2), "d2_sbtc_before");
evalc("dep2 ROCK before withdrawals", rockBal(DEP2), "d2_rock_before");
evalc("whale sBTC before withdrawals", sbtcBal(HIGHROLLER), "hr_sbtc_before");
evalc("whale ROCK before withdrawals", rockBal(HIGHROLLER), "hr_rock_before_wd");
call("dep1 withdraws after unlock", DEP1, SINGLE_CID, "withdraw-lp-tokens", [],
  `(ok u${DEP1_LP})`);
call("dep1 double-withdraw -> err u408", DEP1, SINGLE_CID, "withdraw-lp-tokens", [], "(err u408)");
evalc("dep1 sBTC after withdraw", sbtcBal(DEP1), "d1_sbtc_after");
evalc("dep1 ROCK after withdraw", rockBal(DEP1), "d1_rock_after");
call("stranger cannot push dep2 out -> err u403", STRANGER, SINGLE_CID, "withdraw-lp-tokens-depositor",
  [standardPrincipalCV(DEP2)], "(err u403)");
call("depositor pushes dep2's withdrawal", HIGHROLLER, SINGLE_CID, "withdraw-lp-tokens-depositor",
  [standardPrincipalCV(DEP2)], `(ok u${DEP2_LP})`);
evalc("dep2 sBTC after withdrawals", sbtcBal(DEP2), "d2_sbtc_after");
evalc("dep2 ROCK after withdrawals", rockBal(DEP2), "d2_rock_after");
evalc("whale sBTC after withdrawals", sbtcBal(HIGHROLLER), "hr_sbtc_after");
evalc("whale ROCK after withdrawals", rockBal(HIGHROLLER), "hr_rock_after_wd");
evalc("single LP at end (0)", `(contract-call? '${POOL_CID} get-balance '${SINGLE_CID})`, "singleLpEnd");
evalc("single sBTC at end (0)", sbtcBal(SINGLE_CID), "singleSbtcEnd");
evalc("single ROCK at end (0)", rockBal(SINGLE_CID), "singleRockEnd");

// =====================================================================
// Run + verify
// =====================================================================
function decodeTx(s) {
  const r = s?.Result?.Transaction;
  if (!r) return { ok: false, str: "<no transaction result>" };
  if ("Err" in r) return { ok: false, str: `ENGINE-ERR: ${JSON.stringify(r.Err).slice(0, 200)}` };
  try {
    return { ok: true, str: cvToString(deserializeCV(r.Ok.result)) };
  } catch (e) {
    return { ok: false, str: `decode-failed(${r.Ok.result}): ${e.message}` };
  }
}
function decodeEval(s) {
  const r = s?.Result?.Eval;
  if (!r) return "<no eval result>";
  if (!("Ok" in r)) return `ERR: ${JSON.stringify(r.Err).slice(0, 200)}`;
  try {
    return cvToString(deserializeCV(r.Ok));
  } catch {
    return r.Ok;
  }
}
const bare = (s) => BigInt((String(s).match(/u(\d+)/) || [])[1] ?? "-1");

async function main() {
  console.log("=== ROCK relaunch (gated pool-3 + 1B single-sided) -- stxer mainnet fork ===\n");
  const sessionId = await b.run();
  const url = `https://stxer.xyz/simulations/mainnet/${sessionId}`;
  console.log(`Submitted. Fetching results...\n${url}\n`);

  const res = await getSimulationResult(sessionId);
  const captured = {};
  let pass = 0, fail = 0;

  res.steps.forEach((s, i) => {
    const p = plan[i];
    if (!p) return;
    if (p.kind === "deploy") {
      const ok = !("Err" in (s?.Result?.Transaction || {}));
      console.log(`${ok ? "✅" : "❌"} [${i}] ${p.label}`);
      ok ? pass++ : fail++;
    } else if (p.kind === "tx") {
      const d = decodeTx(s);
      if (p.capture) captured[p.capture] = d.str;
      const ok =
        typeof p.expect === "function" ? p.expect(d.str) :
        p.expect instanceof RegExp ? p.expect.test(d.str) :
        d.str === p.expect;
      console.log(`${ok ? "✅" : "❌"} [${i}] ${p.label}\n        got ${d.str.slice(0, 160)}${ok ? "" : `\n        EXPECTED ${p.expect}`}`);
      ok ? pass++ : fail++;
    } else if (p.kind === "eval") {
      const v = decodeEval(s);
      if (p.capture) captured[p.capture] = v;
      console.log(`ℹ️  [${i}] ${p.label}: ${String(v).slice(0, 180)}`);
    } else if (p.kind === "advance") {
      console.log(`⏩ [${i}] ${p.label}`);
    }
  });

  console.log("\n--- numeric cross-checks ---");
  const check = (label, got, want) => {
    const ok = got === want;
    console.log(`${ok ? "✅" : "❌"} ${label}: ${got}${ok ? "" : ` (want ${want})`}`);
    ok ? pass++ : fail++;
  };
  const near = (label, got, want, tol) => {
    const diff = got > want ? got - want : want - got;
    const ok = diff <= tol;
    console.log(`${ok ? "✅" : "❌"} ${label}: ${got} (want ${want} +-${tol})`);
    ok ? pass++ : fail++;
  };

  // vault accounting: exact pairing at the frozen ratio
  check("vault seeded with exactly 1e15 uROCK", bare(captured.vaultSeed), VAULT_SEED);
  check("vault ROCK after deposits == seed - used", bare(captured.vaultAfterDeps), VAULT_SEED - TOKEN_USED);
  check("dep1 entitlement == 100k LP", bare(captured.dep1lp), DEP1_LP);
  check("sweep returned exactly the unused ROCK",
    bare(captured.hr_rock_after_sweep) - bare(captured.hr_rock_before_sweep), SWEEP_EXPECTED);
  check("vault ROCK zero after sweep", bare(captured.vaultAfterSweep), 0n);

  // faktory fee: buy leg = 0.1% of 20,000 sats = 20 sats minimum
  const feeDelta = bare(captured.fee_after) - bare(captured.fee_before);
  check("faktory fee >= 20 sats", feeDelta >= 20n, true);

  // 60/40 both sides: users kept 60%, depositor got 40% of BOTH exits
  const d1Sbtc = bare(captured.d1_sbtc_after) - bare(captured.d1_sbtc_before);
  const d1Rock = bare(captured.d1_rock_after) - bare(captured.d1_rock_before);
  const d2Sbtc = bare(captured.d2_sbtc_after) - bare(captured.d2_sbtc_before);
  const d2Rock = bare(captured.d2_rock_after) - bare(captured.d2_rock_before);
  const hrSbtc = bare(captured.hr_sbtc_after) - bare(captured.hr_sbtc_before);
  const hrRock = bare(captured.hr_rock_after_wd) - bare(captured.hr_rock_before_wd);
  check("dep1 received sBTC on exit (> 0)", d1Sbtc > 0n, true);
  check("dep1 received ROCK on exit (> 0)", d1Rock > 0n, true);
  check("dep2 received sBTC on exit (> 0)", d2Sbtc > 0n, true);
  // users' 60% vs depositor's 40%: hr == (d1+d2) * 40/60, floor dust allowed
  near("depositor sBTC == users' sBTC * 40/60", hrSbtc, ((d1Sbtc + d2Sbtc) * 40n) / 60n, 4n);
  near("depositor ROCK == users' ROCK * 40/60", hrRock, ((d1Rock + d2Rock) * 40n) / 60n, 4n);
  // nothing stranded in the single
  check("single LP at end == 0", bare(captured.singleLpEnd), 0n);
  check("single sBTC at end == 0", bare(captured.singleSbtcEnd), 0n);
  check("single ROCK at end == 0", bare(captured.singleRockEnd), 0n);

  console.log(`\n=== ${pass} passed, ${fail} failed ===`);
  console.log(`View: ${url}`);
  if (fail > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
