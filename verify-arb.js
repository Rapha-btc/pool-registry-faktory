// verify-arb.js - self-asserting stxer mainnet-fork harness for the welsh / rock
// arb contracts (DRAFTS). Deploys as Clarity 5 (as-contract? allowances, current-contract),
// approves the contract as a core-v2 caller (as simul-leo-arb.js does), evals
// every check-* quote at two sizes, then fires every arb-* route. Arbs are
// profit-or-revert, so on a fork a route is green when it returns (ok ...) OR
// (err u1001) ERR-NO-PROFIT; anything else (engine error, unexpected err) fails.
//
// Run: node verify-arb.js welsh   |   node verify-arb.js rock
import fs from "node:fs";
import { uintCV, contractPrincipalCV, ClarityVersion, cvToString, deserializeCV } from "@stacks/transactions";
import { SimulationBuilder, getSimulationResult } from "stxer";

const which = process.argv[2];
const CFG = {
  welsh: {
    name: "welsh-arb-faktory",
    holder: "SP3AP6DRSQ6P4FETB5M33D082Q2ABGJW60MT6103Q", // ~745M WELSH
    amounts: [100000000000n, 1000000000000n], // 100k, 1M WELSH
    routes: ["fak-bit-bit", "fak-vel-vel", "bit-bit-fak", "vel-vel-fak",
             "fak-bit-alex", "fak-vel-alex", "alex-bit-fak", "alex-vel-fak"],
    token: "'SP3NE50GEXFG9SZGTT51P40X2CKYSZ5CC4ZTZ7A2G.welshcorgicoin-token",
  },
  rock: {
    name: "rock-arb-faktory",
    holder: "SP1J9JVDWMAM63RZM54R43TK84XCT85C2W254TMYX", // ~3.2B ROCK
    amounts: [10000000000000n, 100000000000000n], // 10M, 100M ROCK
    routes: ["fak-bit-vel", "fak-vel-vel", "vel-bit-fak", "vel-vel-fak"],
    token: "'SP4M2C88EE8RQZPYTC4PZ88CE16YGP825EYF6KBQ.stacks-rock",
  },
}[which];
if (!CFG) { console.error("usage: node verify-arb.js welsh|rock"); process.exit(2); }

const DEPLOYER = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22";
const C = `${DEPLOYER}.${CFG.name}`;
const src = fs.readFileSync(process.env.SRC || `./contracts/${CFG.name}.clar`, "utf8")
  .split("\n").filter((l) => !l.trim().startsWith(";;") && l.trim() !== "").join("\n");

const steps = [];
const b = SimulationBuilder.new()
  .withSender(DEPLOYER)
  .addContractDeploy({ contract_name: CFG.name, source_code: src, clarity_version: ClarityVersion.Clarity5 });
steps.push({ label: `deploy ${CFG.name} (Clarity 5)`, kind: "deploy" });
b.addContractCall({
  contract_id: `${DEPLOYER}.fakfun-core-v2`, function_name: "approve-caller",
  function_args: [contractPrincipalCV(DEPLOYER, CFG.name)],
});
steps.push({ label: "core-v2 approve-caller", kind: "tx-ok" });

for (const amt of CFG.amounts) {
  for (const r of CFG.routes) {
    b.addEvalCode(C, `(check-${r} u${amt})`);
    steps.push({ label: `check-${r} ${amt}`, kind: "eval" });
  }
}
b.withSender(CFG.holder);
for (const r of CFG.routes) {
  b.addContractCall({ contract_id: C, function_name: `arb-${r}`, function_args: [uintCV(CFG.amounts[0]), uintCV(1)] });
  steps.push({ label: `arb-${r} ${CFG.amounts[0]}`, kind: "arb" });
}
for (const [label, code] of [
  ["residue STX", "(stx-get-balance current-contract)"],
  ["residue sBTC", "(contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token get-balance current-contract)"],
  ["residue token", `(contract-call? ${CFG.token} get-balance current-contract)`],
]) { b.addEvalCode(C, code); steps.push({ label, kind: "residue" }); }

function decodeTx(s) {
  const r = s?.Result?.Transaction; if (!r) return "<no tx>";
  if ("Err" in r) return `ENGINE-ERR ${JSON.stringify(r.Err)}`;
  try { return cvToString(deserializeCV(r.Ok.result)); } catch { return `raw:${r.Ok?.result}`; }
}
function decodeEval(s) {
  const r = s?.Result?.Eval; if (!r) return "<no eval>";
  if (!("Ok" in r)) return `ERR ${JSON.stringify(r.Err)}`;
  try { return cvToString(deserializeCV(r.Ok)); } catch { return r.Ok; }
}
let checks = 0, failures = 0;
function assert(label, v, ok) { checks++; if (ok) console.log(`  ok   ${label}: ${String(v).slice(0, 120)}`); else { failures++; console.log(`  FAIL ${label}: ${String(v).slice(0, 200)}`); } }

const sid = await b.run();
console.log(`\nView: https://stxer.xyz/simulations/mainnet/${sid}\n`);
const res = await getSimulationResult(sid);
steps.forEach((st, i) => {
  const s = res.steps[i];
  if (st.kind === "eval") { const v = decodeEval(s); assert(st.label, v, !String(v).startsWith("ERR") && v !== "<no eval>"); }
  else if (st.kind === "residue") { const v = decodeEval(s); assert(st.label, v, v === "u0" || v === "(ok u0)"); }
  else if (st.kind === "arb") { const v = decodeTx(s); assert(st.label, v, String(v).startsWith("(ok") || v === "(err u1001)"); }
  else { const v = decodeTx(s); assert(st.label, v, String(v).startsWith("(ok")); }
});
console.log(`\n${checks - failures}/${checks} checks green`);
if (failures > 0) process.exit(1);
