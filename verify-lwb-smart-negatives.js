// verify-lwb-smart-negatives.js
// Bug-hunting harness for lwb-smart-faktory: error paths, estimate/actual
// parity (min-out = exact estimate must pass, +1 must revert), dust and
// large sizes, zero residue after every section, and three sabotaged twins
// whose allowances are one unit short (proves the allowances bind).
//
// Run: node verify-lwb-smart-negatives.js
import fs from "node:fs";
import { uintCV, boolCV, ClarityVersion, cvToString, deserializeCV } from "@stacks/transactions";
import { SimulationBuilder, getSimulationResult } from "stxer";

const DEPLOYER = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22";
const OK = `${DEPLOYER}.lwb-smart-faktory`;
const SBTC_HOLDER = "SP2C7BCAP2NH3EYWCCVHJ6K0DMZBXDFKQ56KR7QN2";
const STX_HOLDER = "SP9BP4PN74CNR5XT7CMAMBPA0GWC9HMB69HVVV51";
const LWB_HOLDER = "SPZ2X7Q0Z69KTN7SZF90MR9AZGZ2ETXFGMFXKKN8"; // 1.79B LWB
const TOKEN = "SP277HZA8AGXV42MZKDW5B2NNN61RHQ42MTAHVNB1.little-whiny-bitch-stxcity";

const SBTC_AMOUNT = 100000n, STX_AMOUNT = 100000000n, LWB_AMOUNT = 10000000000000n; // 10M LWB
const ERR_SLIPPAGE = "u1000", ERR_INVALID_RATIO = "u1002";

const src = fs.readFileSync(process.env.SRC || "./contracts/lwb-smart-faktory.clar", "utf8");
const sabotage = (name, from, to) => {
  const s = src.replace(from, to);
  if (s === src) { console.error(`sabotage ${name} did not apply`); process.exit(1); }
  return s;
};
// 1) sBTC fak-leg allowance 1 sat short (buy-with-sbtc pure fak)
const tightSbtc = sabotage("sbtc", "(as-contract? ((with-ft SBTC SBTC-ASSET fak-amount))", "(as-contract? ((with-ft SBTC SBTC-ASSET (- fak-amount u1)))");
// 2) token payout allowance 1 unit short (every buy)
const tightPayout = sabotage("payout", "(as-contract? ((with-ft TOKEN TOKEN-ASSET total-token-out))", "(as-contract? ((with-ft TOKEN TOKEN-ASSET (- total-token-out u1)))");
// 3) STX dex-leg allowance 1 ustx short (buy-with-stx pure dex, first occurrence = buy-with-stx alex leg)
const tightStx = sabotage("stx", "(as-contract? ((with-stx alex-amount))", "(as-contract? ((with-stx (- alex-amount u1)))");

const steps = [];
const push = (label, want) => steps.push({ label, want });
const isOk = (v) => v.startsWith("(ok");
const b = SimulationBuilder.new({ stacksNodeAPI: process.env.STACKS_API || "http://77.42.3.101/stacks-api" }).withSender(DEPLOYER);
for (const [name, code] of [["lwb-smart-faktory", src], ["lwb-tight-sbtc", tightSbtc], ["lwb-tight-payout", tightPayout], ["lwb-tight-stx", tightStx]]) {
  b.withSender(DEPLOYER).addContractDeploy({ contract_name: name, source_code: code, clarity_version: ClarityVersion.Clarity5 });
  push(`deploy ${name}`, isOk);
}
const call = (contract, fn, sender, args) => b.withSender(sender).addContractCall({ contract_id: contract, function_name: fn, function_args: args });
const legs = [
  ["buy-with-sbtc", SBTC_HOLDER, SBTC_AMOUNT],
  ["buy-with-stx", STX_HOLDER, STX_AMOUNT],
  ["sell-for-sbtc", LWB_HOLDER, LWB_AMOUNT],
  ["sell-for-stx", LWB_HOLDER, LWB_AMOUNT],
];

// --- ERR-INVALID-RATIO ---
for (const [fn, s, a] of legs) { call(OK, fn, s, [uintCV(a), uintCV(1), uintCV(101n), boolCV(true)]); push(`${fn} ratio=101 -> ERR-INVALID-RATIO`, (v) => v.includes(ERR_INVALID_RATIO)); }
// --- ERR-SLIPPAGE, both bridges ---
for (const flag of [true, false]) for (const [fn, s, a] of legs) { call(OK, fn, s, [uintCV(a), uintCV(10n ** 30n), uintCV(50n), boolCV(flag)]); push(`${fn} min-out=1e30 ${flag ? "bitflow" : "velar"} -> ERR-SLIPPAGE`, (v) => v.includes(ERR_SLIPPAGE)); }

// --- allowance binds: twins abort, control succeeds ---
call(`${DEPLOYER}.lwb-tight-sbtc`, "buy-with-sbtc", SBTC_HOLDER, [uintCV(SBTC_AMOUNT), uintCV(1), uintCV(100n), boolCV(true)]); push("tight sBTC fak-leg allowance aborts", (v) => !isOk(v));
call(OK, "buy-with-sbtc", SBTC_HOLDER, [uintCV(SBTC_AMOUNT), uintCV(1), uintCV(100n), boolCV(true)]); push("control buy-with-sbtc fak=100 ok", isOk);
call(`${DEPLOYER}.lwb-tight-payout`, "buy-with-sbtc", SBTC_HOLDER, [uintCV(SBTC_AMOUNT), uintCV(1), uintCV(50n), boolCV(true)]); push("tight token payout allowance aborts", (v) => !isOk(v));
call(`${DEPLOYER}.lwb-tight-stx`, "buy-with-stx", STX_HOLDER, [uintCV(STX_AMOUNT), uintCV(1), uintCV(100n), boolCV(true)]); push("tight STX dex-leg allowance aborts", (v) => !isOk(v));
call(OK, "buy-with-stx", STX_HOLDER, [uintCV(STX_AMOUNT), uintCV(1), uintCV(100n), boolCV(true)]); push("control buy-with-stx alex=100 ok", isOk);

// --- estimate/actual parity via the smart-* wrappers ---
// eval compare-* (state S) -> call with best+1 (must revert, S unchanged) -> call with best (must succeed).
const parity = [
  ["smart-buy-with-sbtc", "compare-sbtc-to-token-routes", SBTC_HOLDER, SBTC_AMOUNT],
  ["smart-buy-with-stx", "compare-stx-to-token-routes", STX_HOLDER, STX_AMOUNT],
  ["smart-sell-for-sbtc", "compare-token-to-sbtc-routes", LWB_HOLDER, LWB_AMOUNT],
  ["smart-sell-for-stx", "compare-token-to-stx-routes", LWB_HOLDER, LWB_AMOUNT],
];
const bestOf = (v) => BigInt(/\(best-output u(\d+)\)/.exec(v)[1]);
for (const [fn, cmp, sender, amount] of parity) {
  b.addEvalCode(OK, `(${cmp} u${amount})`); push(`eval ${cmp}`, (v) => /best-output u\d+/.test(v));
  // deferred args: filled from the eval result at run time is impossible in a
  // builder, so eval the exact call inline from the contract's context instead.
  b.addEvalCode(OK, `(let ((best (get best-output (${cmp} u${amount})))) (ok best))`); push(`eval best ${fn}`, isOk);
}
// The builder cannot feed an eval result into a later tx, so parity is done with
// a contract-context eval that calls the public fn with min-out = best+1 and
// min-out = best. Evals inside the router's context run with tx-sender =
// the holder set below.
for (const [fn, cmp, sender, amount] of parity) {
  b.withSender(sender).addEvalCode(OK, `(let ((best (get best-output (${cmp} u${amount})))) (${fn} u${amount} (+ best u1)))`);
  push(`${fn} min-out=best+1 -> ERR-SLIPPAGE`, (v) => v.includes(ERR_SLIPPAGE));
  b.withSender(sender).addEvalCode(OK, `(let ((best (get best-output (${cmp} u${amount})))) (${fn} u${amount} best))`);
  push(`${fn} min-out=best (exact) -> ok`, isOk);
}

// --- dust: 1 unit and 10 units on every leg, split 50 both bridges. Either a
// clean (ok ...) or a clean (err ...), never an engine abort; residue must be 0.
for (const flag of [true, false]) for (const dust of [1n, 10n]) for (const [fn, s] of legs) {
  call(OK, fn, s, [uintCV(dust), uintCV(0), uintCV(50n), boolCV(flag)]);
  push(`${fn} dust=${dust} ${flag ? "bitflow" : "velar"} -> clean result`, (v) => isOk(v) || v.startsWith("(err"));
}
// --- large: 1M sats (3x the fak pool), 500 STX, 300M LWB (~38% of fak pool) ---
for (const flag of [true, false]) {
  call(OK, "buy-with-sbtc", SBTC_HOLDER, [uintCV(1000000n), uintCV(1), uintCV(50n), boolCV(flag)]); push(`buy-with-sbtc 1M sats ${flag}`, isOk);
  call(OK, "buy-with-stx", STX_HOLDER, [uintCV(500000000n), uintCV(1), uintCV(50n), boolCV(flag)]); push(`buy-with-stx 500 STX ${flag}`, isOk);
  call(OK, "sell-for-sbtc", LWB_HOLDER, [uintCV(300000000000000n), uintCV(1), uintCV(50n), boolCV(flag)]); push(`sell-for-sbtc 300M LWB ${flag}`, isOk);
  call(OK, "sell-for-stx", LWB_HOLDER, [uintCV(300000000000000n), uintCV(1), uintCV(50n), boolCV(flag)]); push(`sell-for-stx 300M LWB ${flag}`, isOk);
  call(OK, "smart-buy-with-sbtc", SBTC_HOLDER, [uintCV(1000000n), uintCV(1)]); push(`smart-buy-with-sbtc 1M sats`, isOk);
  call(OK, "smart-sell-for-stx", LWB_HOLDER, [uintCV(300000000000000n), uintCV(1)]); push(`smart-sell-for-stx 300M LWB`, isOk);
}
// --- zero residue after everything ---
b.addEvalCode(OK, "(stx-get-balance current-contract)"); push("residue STX", (v) => v === "u0");
b.addEvalCode(OK, "(contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token get-balance current-contract)"); push("residue sBTC", (v) => v === "(ok u0)");
b.addEvalCode(OK, `(contract-call? '${TOKEN} get-balance current-contract)`); push("residue LWB", (v) => v === "(ok u0)");

function decode(s) {
  const r = s?.Result?.Transaction ?? s?.Result?.Eval ?? s?.Result?.ContractCall;
  const any = s?.Result ? Object.values(s.Result)[0] : null;
  const x = r ?? any;
  if (!x) return "<no result>";
  if ("Err" in x) return `ENGINE-ERR ${JSON.stringify(x.Err).slice(0, 200)}`;
  const raw = x.Ok?.result ?? x.Ok?.value ?? x.Ok;
  try { return cvToString(deserializeCV(raw)); } catch { return `raw:${JSON.stringify(raw).slice(0, 120)}`; }
}
const sid = await b.run();
console.log(`\nView: https://stxer.xyz/simulations/mainnet/${sid}\n`);
const res = await getSimulationResult(sid);
let fails = 0;
steps.forEach((st, i) => {
  const v = String(decode(res.steps[i]));
  const ok = st.want(v);
  if (!ok) fails++;
  console.log(`  ${ok ? "ok  " : "FAIL"} ${st.label}: ${v.slice(0, 140)}`);
});
console.log(`\n${steps.length - fails}/${steps.length} checks green`);
if (fails) process.exit(1);
