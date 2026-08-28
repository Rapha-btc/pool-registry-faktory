// verify-welsh-arb-imbalance.js - proves welsh-arb-faktory actually fires.
// 1. deploy + approve-caller, quote every route (expect no edge)
// 2. an sBTC whale buys WELSH on welshcorgicoin-faktory-pool-v2 via fakfun-core-v2
//    (pool is ~236k sats deep, so 100k sats pushes WELSH well above BitFlow/ALEX)
// 3. quote again (expect fak-first routes profitable), then execute them: each
//    must return (ok {token-in, token-out}) with token-out > token-in, and the
//    reverse routes must still revert ERR-NO-PROFIT.
// Run: node verify-welsh-arb-imbalance.js
import fs from "node:fs";
import { uintCV, someCV, bufferCV, contractPrincipalCV, ClarityVersion, cvToString, deserializeCV } from "@stacks/transactions";
import { SimulationBuilder, getSimulationResult } from "stxer";

const DEPLOYER = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22";
const NAME = "welsh-arb-faktory";
const C = `${DEPLOYER}.${NAME}`;
const SBTC_WHALE = "SP2C7BCAP2NH3EYWCCVHJ6K0DMZBXDFKQ56KR7QN2"; // ~40 BTC
const WELSH_HOLDER = "SP3AP6DRSQ6P4FETB5M33D082Q2ABGJW60MT6103Q"; // ~745M WELSH
const IMBALANCE_SATS = 100000n; // buy on the fak pool
const ARB_AMOUNT = 100000000000n; // 100k WELSH per arb
const FAK_FIRST = ["fak-bit-bit", "fak-vel-vel", "fak-bit-alex", "fak-vel-alex"];
const REVERSE = ["bit-bit-fak", "vel-vel-fak", "alex-bit-fak", "alex-vel-fak"];

const src = fs.readFileSync(`./contracts/${NAME}.clar`, "utf8")
  .split("\n").filter((l) => !l.trim().startsWith(";;") && l.trim() !== "").join("\n");

const steps = [];
const b = SimulationBuilder.new().withSender(DEPLOYER)
  .addContractDeploy({ contract_name: NAME, source_code: src, clarity_version: ClarityVersion.Clarity5 });
steps.push({ label: "deploy", kind: "tx-ok" });
b.addContractCall({ contract_id: `${DEPLOYER}.fakfun-core-v2`, function_name: "approve-caller",
  function_args: [contractPrincipalCV(DEPLOYER, NAME)] });
steps.push({ label: "approve-caller", kind: "tx-ok" });

for (const r of [...FAK_FIRST, ...REVERSE]) { b.addEvalCode(C, `(check-${r} u${ARB_AMOUNT})`); steps.push({ label: `BEFORE check-${r}`, kind: "quote" }); }

b.withSender(SBTC_WHALE).addContractCall({
  contract_id: `${DEPLOYER}.fakfun-core-v2`, function_name: "execute",
  function_args: [contractPrincipalCV(DEPLOYER, "welshcorgicoin-faktory-pool-v2"), uintCV(IMBALANCE_SATS), someCV(bufferCV(Buffer.from("00", "hex")))],
});
steps.push({ label: `IMBALANCE: whale buys WELSH with ${IMBALANCE_SATS} sats on the fak pool`, kind: "tx-ok" });

for (const r of [...FAK_FIRST, ...REVERSE]) { b.addEvalCode(C, `(check-${r} u${ARB_AMOUNT})`); steps.push({ label: `AFTER  check-${r}`, kind: "quote", expectProfit: FAK_FIRST.includes(r) }); }

b.withSender(WELSH_HOLDER);
FAK_FIRST.forEach((r, i) => { b.addContractCall({ contract_id: C, function_name: `arb-${r}`, function_args: [uintCV(ARB_AMOUNT), uintCV(1)] }); steps.push({ label: i === 0 ? `EXEC arb-${r} (must profit)` : `EXEC arb-${r} (profit, or u1001 once earlier arbs closed the gap)`, kind: i === 0 ? "arb-profit" : "arb-noprofit" }); });
for (const r of REVERSE) { b.addContractCall({ contract_id: C, function_name: `arb-${r}`, function_args: [uintCV(ARB_AMOUNT), uintCV(1)] }); steps.push({ label: `EXEC arb-${r} (reverse, expect no profit)`, kind: "arb-noprofit" }); }
for (const [label, code] of [
  ["residue STX", "(stx-get-balance current-contract)"],
  ["residue sBTC", "(contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token get-balance current-contract)"],
  ["residue WELSH", "(contract-call? 'SP3NE50GEXFG9SZGTT51P40X2CKYSZ5CC4ZTZ7A2G.welshcorgicoin-token get-balance current-contract)"],
]) { b.addEvalCode(C, code); steps.push({ label, kind: "residue" }); }

const decodeTx = (s) => { const r = s?.Result?.Transaction; if (!r) return "<no tx>"; if ("Err" in r) return `ENGINE-ERR ${JSON.stringify(r.Err)}`; try { return cvToString(deserializeCV(r.Ok.result)); } catch { return `raw:${r.Ok?.result}`; } };
const decodeEval = (s) => { const r = s?.Result?.Eval; if (!r) return "<no eval>"; if (!("Ok" in r)) return `ERR ${JSON.stringify(r.Err)}`; try { return cvToString(deserializeCV(r.Ok)); } catch { return r.Ok; } };
const num = (str, key) => { const m = String(str).match(new RegExp(`\\(${key} u(\\d+)\\)`)); return m ? BigInt(m[1]) : null; };
let checks = 0, failures = 0;
const assert = (label, v, ok) => { checks++; console.log(`  ${ok ? "ok  " : "FAIL"} ${label}: ${String(v).slice(0, 150)}`); if (!ok) failures++; };

const sid = await b.run();
console.log(`\nView: https://stxer.xyz/simulations/mainnet/${sid}\n`);
const res = await getSimulationResult(sid);
steps.forEach((st, i) => {
  const s = res.steps[i];
  if (st.kind === "quote") {
    const v = decodeEval(s); const p = num(v, "profit"); const inn = num(v, "amt-in"); const out = num(v, "amt-out");
    const summary = `in ${inn} out ${out} profit ${p}`;
    if (st.expectProfit === undefined) assert(st.label, summary, p !== null);
    else assert(st.label, summary, st.expectProfit ? p > 0n : true);
  } else if (st.kind === "arb-profit") {
    const v = decodeTx(s); const inn = num(v, "token-in"); const out = num(v, "token-out");
    assert(st.label, v, String(v).startsWith("(ok") && out > inn);
  } else if (st.kind === "arb-noprofit") {
    const v = decodeTx(s); assert(st.label, v, v === "(err u1001)" || String(v).startsWith("(ok"));
  } else if (st.kind === "residue") {
    const v = decodeEval(s); assert(st.label, v, v === "u0" || v === "(ok u0)");
  } else { const v = decodeTx(s); assert(st.label, v, String(v).startsWith("(ok")); }
});
console.log(`\n${checks - failures}/${checks} checks green`);
if (failures > 0) process.exit(1);
