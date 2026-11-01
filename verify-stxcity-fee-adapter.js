// verify-stxcity-fee-adapter.js
// Mainnet-fork (stxer) harness for stxcity-fee-adapter (fee 1% default, cap 3%).
// Venues: canex-stxcity-dex (curve, not graduated), xyk-pool-stx-aiearn-v-1-1
// (Bitflow, xyk-core-v-1-2). Checks balance deltas (fee recipient exact, user
// in/out exact, adapter holds 0 STX / 0 tokens after every call), slippage on
// all three paths ("just above" via quote-in-the-same-eval), guards, owner flow.
//
// Run: node verify-stxcity-fee-adapter.js
import fs from "node:fs";
import { uintCV, boolCV, listCV, contractPrincipalCV, standardPrincipalCV, ClarityVersion, cvToString, deserializeCV } from "@stacks/transactions";
import { SimulationBuilder, getSimulationResult } from "stxer";

const DEPLOYER = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22";
const ADAPTER = `${DEPLOYER}.stxcity-fee-adapter`;
const PROBE = `${DEPLOYER}.stxcity-adapter-probe`;
const A = "SP2XCME6ED8RERGR9R7YDZW7CA6G3F113Y8JMVA46";
const WHALE = "SP3HXJJMJQ06GNAZ8XWDN1QM48JEDC6PP6W3YZPZJ"; // ~1.6M STX
const FEE_R = "SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE"; // fee recipient on fork
const STRANGER = "SP9BP4PN74CNR5XT7CMAMBPA0GWC9HMB69HVVV51";
const CORE = "SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-core-v-1-2";
const STX_TOKEN = "SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2";
const DEX = `${A}.canex-stxcity-dex`, CTOK = `${A}.canex-stxcity`;
const POOL = `${A}.xyk-pool-stx-aiearn-v-1-1`, PTOK = `${A}.aiearn-stxcity`;
const NODE = process.env.STACKS_API || "http://77.42.3.101/stacks-api";
const cp = (id) => { const [a, n] = id.split("."); return contractPrincipalCV(a, n); };
const fee1 = (x) => (x * 100n) / 10000n;

const SRC = fs.readFileSync(process.env.SRC || "./contracts/stxcity-fee-adapter.clar", "utf8")
  .split("\n").filter((l) => !/^\s*;;/.test(l)).map((l) => l.replace(/\s;;.*$/, "")).join("\n");
// probe: quote + adapter call in ONE tx sent by the user (stxer evals all run as
// the builder's last sender, so trade cases cannot be evals). A tx err rolls back.
const PROBE_SRC = `
(define-public (curve (stx uint) (net uint) (plus uint))
  (let ((q (get buyable-token (unwrap-panic (contract-call? '${A}.canex-stxcity-dex get-buyable-tokens net)))))
    (let ((out (try! (contract-call? '${ADAPTER} buy-curve '${A}.canex-stxcity-dex '${A}.canex-stxcity stx (+ q plus)))))
      (ok { q: q, out: out }))))
(define-public (bpool (stx uint) (net uint) (plus uint))
  (let ((q (unwrap-panic (contract-call? '${CORE} get-dy '${POOL} '${STX_TOKEN} '${PTOK} net))))
    (let ((out (try! (contract-call? '${ADAPTER} buy-pool '${POOL} '${STX_TOKEN} '${PTOK} stx (+ q plus)))))
      (ok { q: q, out: out }))))
(define-public (spool (tokens uint) (plus uint))
  (let ((q (unwrap-panic (contract-call? '${CORE} get-dx '${POOL} '${STX_TOKEN} '${PTOK} tokens)))
        (n (- q (contract-call? '${ADAPTER} fee-of q))))
    (let ((out (try! (contract-call? '${ADAPTER} sell-pool '${POOL} '${STX_TOKEN} '${PTOK} tokens (+ n plus)))))
      (ok { q: q, n: n, out: out }))))`;

// initial pool state -> exact Bitflow x-for-y quote for the first buy-pool
const poolRaw = await fetch(`${NODE}/v2/contracts/call-read/${POOL.replace(".", "/")}/get-pool`, {
  method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ sender: DEPLOYER, arguments: [] }),
}).then((r) => r.json());
const poolStr = cvToString(deserializeCV(poolRaw.result));
const pg = (k) => BigInt(new RegExp(`\\(${k} u(\\d+)\\)`).exec(poolStr)[1]);
if (!poolStr.includes(CORE) || !poolStr.includes(`(x-token ${STX_TOKEN})`) || !poolStr.includes(`(y-token ${PTOK})`)) {
  console.error("aiearn pool is not STX/aiearn on xyk-core-v-1-2:", poolStr); process.exit(2);
}
function dyOf(dx) {
  const dxn = dx - (dx * pg("x-protocol-fee")) / 10000n - (dx * pg("x-provider-fee")) / 10000n;
  return (pg("y-balance") * dxn) / (pg("x-balance") + dxn);
}

const plan = [];
const b = SimulationBuilder.new({ stacksNodeAPI: NODE });
const tx = (label, sender, fn, args, want, cap) => { b.withSender(sender).addContractCall({ contract_id: ADAPTER, function_name: fn, function_args: args }); plan.push({ label, want, cap }); };
const ev = (label, sender, code, want, cap, inside = PROBE) => { b.addEvalCode(inside, code); plan.push({ label, want, cap }); };
const ptx = (label, fn, args, want, cap) => { b.withSender(WHALE).addContractCall({ contract_id: PROBE, function_name: fn, function_args: args }); plan.push({ label, want, cap }); };
const snap = (tag) => ev(`snapshot ${tag}`, DEPLOYER, `{ us: (stx-get-balance '${WHALE}), rs: (stx-get-balance '${FEE_R}), as: (stx-get-balance '${ADAPTER}),
  uc: (unwrap-panic (contract-call? '${CTOK} get-balance '${WHALE})), ua: (unwrap-panic (contract-call? '${PTOK} get-balance '${WHALE})),
  ac: (unwrap-panic (contract-call? '${CTOK} get-balance '${ADAPTER})), aa: (unwrap-panic (contract-call? '${PTOK} get-balance '${ADAPTER})) }`, () => true, `s_${tag}`);
const isOk = (v) => v.startsWith("(ok");
const isErr = (code) => (v) => v === `(err u${code})`;
const P = { dex: cp(DEX), ctok: cp(CTOK), pool: cp(POOL), stx: cp(STX_TOKEN), ptok: cp(PTOK) };
const adapterCall = (fn, args) => `(contract-call? '${ADAPTER} ${fn} ${args})`;
const POOLARGS = `'${POOL} '${STX_TOKEN} '${PTOK}`;

// ---- setup ----
for (const [name, code] of [["stxcity-fee-adapter", SRC], ["stxcity-adapter-probe", PROBE_SRC]]) {
  b.withSender(DEPLOYER).addContractDeploy({ contract_name: name, source_code: code, clarity_version: ClarityVersion.Clarity5 });
  plan.push({ label: `deploy ${name}`, want: isOk });
}
ev("default fee-bps = u100", DEPLOYER, adapterCall("get-fee-bps", ""), (v) => v === "u100");

// non-owner setters -> u5001
tx("non-owner set-approved -> u5001", WHALE, "set-approved", [listCV([P.dex]), boolCV(true)], isErr(5001));
tx("non-owner set-fee-bps -> u5001", WHALE, "set-fee-bps", [uintCV(50)], isErr(5001));
tx("non-owner set-fee-recipient -> u5001", WHALE, "set-fee-recipient", [standardPrincipalCV(WHALE)], isErr(5001));
tx("non-owner propose-owner -> u5001", WHALE, "propose-owner", [standardPrincipalCV(WHALE)], isErr(5001));
tx("set-fee-bps u301 -> u5005", DEPLOYER, "set-fee-bps", [uintCV(301)], isErr(5005));
tx("set-fee-bps u300 (cap) ok", DEPLOYER, "set-fee-bps", [uintCV(300)], isOk);
tx("set-fee-bps back to u100", DEPLOYER, "set-fee-bps", [uintCV(100)], isOk);
tx("set-fee-recipient FEE_R", DEPLOYER, "set-fee-recipient", [standardPrincipalCV(FEE_R)], isOk);

// unapproved before set-approved -> u5002 (all three paths)
tx("buy-curve unapproved dex -> u5002", WHALE, "buy-curve", [P.dex, P.ctok, uintCV(5_000_000), uintCV(1)], isErr(5002));
tx("buy-pool unapproved pool -> u5002", WHALE, "buy-pool", [P.pool, P.stx, P.ptok, uintCV(5_000_000), uintCV(1)], isErr(5002));
tx("set-approved dex + pool", DEPLOYER, "set-approved", [listCV([P.dex, P.pool]), boolCV(true)], isOk);

// zero amount -> u5003
tx("buy-curve u0 -> u5003", WHALE, "buy-curve", [P.dex, P.ctok, uintCV(0), uintCV(0)], isErr(5003));
tx("buy-pool u0 -> u5003", WHALE, "buy-pool", [P.pool, P.stx, P.ptok, uintCV(0), uintCV(0)], isErr(5003));

// ---- buy-curve ----
const CA = 10_000_000n;
snap("c0");
ev("buy-curve quote get-buyable-tokens(net)", WHALE, `(get buyable-token (unwrap-panic (contract-call? '${DEX} get-buyable-tokens u${CA - fee1(CA)})))`, (v) => /^u\d+$/.test(v), "cq");
tx(`buy-curve canex ${CA} uSTX`, WHALE, "buy-curve", [P.dex, P.ctok, uintCV(CA), uintCV(1)], isOk, "c_out");
snap("c1");
ptx("buy-curve min = quote+1 -> u5004", "curve", [uintCV(CA), uintCV(CA - fee1(CA)), uintCV(1)], isErr(5004));
ptx("buy-curve min = quote exact -> ok, out == quote", "curve", [uintCV(CA), uintCV(CA - fee1(CA)), uintCV(0)], (v) => { const m = /\(out u(\d+)\) \(q u(\d+)\)/.exec(v); return !!m && m[1] === m[2]; });
snap("c2");
tx("buy-curve unapproved glitchart -> u5002", WHALE, "buy-curve", [cp(`${A}.glitchart-stxcity-dex`), cp(`${A}.glitchart-stxcity`), uintCV(5_000_000), uintCV(1)], isErr(5002));

// ---- buy-pool ----
const BA = 10_000_000n, BDY = dyOf(BA - fee1(BA));
snap("b0");
tx(`buy-pool aiearn ${BA} uSTX`, WHALE, "buy-pool", [P.pool, P.stx, P.ptok, uintCV(BA), uintCV(1)], isOk, "b_out");
snap("b1");
ptx("buy-pool min = get-dy+1 -> err (adapter has no own check; core u1020)", "bpool", [uintCV(BA), uintCV(BA - fee1(BA)), uintCV(1)], (v) => v.startsWith("(err"), "b_slip");
snap("b2");

// ---- sell-pool ----
const SA = BDY / 2n;
snap("s0");
tx(`sell-pool aiearn ${SA} tokens`, WHALE, "sell-pool", [P.pool, P.stx, P.ptok, uintCV(SA), uintCV(1)], isOk, "s_out");
snap("s1");
const SB = SA / 4n;
ptx("sell-pool min = achievable net+1 -> u5004", "spool", [uintCV(SB), uintCV(1)], isErr(5004));
snap("s2");
ptx("sell-pool min = achievable net exact -> ok net", "spool", [uintCV(SB), uintCV(0)], (v) => { const m = /\(n u(\d+)\) \(out u(\d+)\)/.exec(v); return !!m && m[1] === m[2]; });
snap("s3");
tx("sell-pool tokens-in u0 -> (what comes back)", WHALE, "sell-pool", [P.pool, P.stx, P.ptok, uintCV(0), uintCV(0)], (v) => v.startsWith("(err"), "s_zero");

// unapprove pool -> u5002 on buy and sell
tx("set-approved pool false", DEPLOYER, "set-approved", [listCV([P.pool]), boolCV(false)], isOk);
tx("buy-pool after unapprove -> u5002", WHALE, "buy-pool", [P.pool, P.stx, P.ptok, uintCV(5_000_000), uintCV(1)], isErr(5002));
snap("u0");
tx("sell-pool after unapprove -> u5002", WHALE, "sell-pool", [P.pool, P.stx, P.ptok, uintCV(SB), uintCV(1)], isErr(5002));
snap("u1");
tx("set-approved pool true", DEPLOYER, "set-approved", [listCV([P.pool]), boolCV(true)], isOk);

// ---- fee recipient == user: no fee transfer, no failure ----
tx("set-fee-recipient = WHALE", DEPLOYER, "set-fee-recipient", [standardPrincipalCV(WHALE)], isOk);
snap("w0");
tx("buy-curve with recipient == user", WHALE, "buy-curve", [P.dex, P.ctok, uintCV(CA), uintCV(1)], isOk);
snap("w1");
tx("buy-pool with recipient == user", WHALE, "buy-pool", [P.pool, P.stx, P.ptok, uintCV(BA), uintCV(1)], isOk);
snap("w2");
tx("sell-pool with recipient == user", WHALE, "sell-pool", [P.pool, P.stx, P.ptok, uintCV(SB), uintCV(1)], isOk, "w_sell");
snap("w3");
tx("set-fee-recipient back to FEE_R", DEPLOYER, "set-fee-recipient", [standardPrincipalCV(FEE_R)], isOk);

// ---- owner handover ----
tx("propose-owner WHALE", DEPLOYER, "propose-owner", [standardPrincipalCV(WHALE)], isOk);
tx("accept-owner by stranger -> u5001", STRANGER, "accept-owner", [], isErr(5001));
tx("accept-owner by WHALE", WHALE, "accept-owner", [], isOk);
ev("get-owner == WHALE", DEPLOYER, adapterCall("get-owner", ""), (v) => v === WHALE);
tx("old owner set-fee-bps -> u5001", DEPLOYER, "set-fee-bps", [uintCV(50)], isErr(5001));
tx("new owner set-fee-bps u50", WHALE, "set-fee-bps", [uintCV(50)], isOk);
tx("accept-owner again (pending cleared) -> u5001", WHALE, "accept-owner", [], isErr(5001));
snap("final");

// ---- run ----
function decode(s) {
  const x = s?.Result ? (s.Result.Transaction ?? s.Result.Eval ?? Object.values(s.Result)[0]) : null;
  if (!x) return "<no result>";
  if ("Err" in x) return `ENGINE-ERR ${JSON.stringify(x.Err).slice(0, 200)}`;
  const raw = x.Ok?.result ?? x.Ok;
  try { return cvToString(deserializeCV(raw)); } catch { return `raw:${JSON.stringify(raw).slice(0, 120)}`; }
}
const sid = await b.run();
const url = `https://stxer.xyz/simulations/mainnet/${sid}`;
console.log(`\nSession: ${sid}\nView: ${url}\n`);
const res = await getSimulationResult(sid);
const cap = {}; let pass = 0, fail = 0;
const check = (label, ok, got = "") => { ok ? pass++ : fail++; console.log(`  ${ok ? "PASS" : "FAIL"} ${label}${ok ? "" : `  got ${got}`}`); };
plan.forEach((p, i) => {
  const v = decode(res.steps[i]);
  if (p.cap) cap[p.cap] = v;
  if (p.label.startsWith("snapshot")) { if (!v.startsWith("(tuple")) check(p.label, false, v); return; }
  check(`[${i}] ${p.label}: ${v.slice(0, 90)}`, p.want(v), v);
});
const S = (tag) => { const t = cap[`s_${tag}`] || ""; const o = {}; for (const m of t.matchAll(/\((\w+) u(\d+)\)/g)) o[m[1]] = BigInt(m[2]); return o; };
const D = (a, b2, k) => S(b2)[k] - S(a)[k];
const U = (v) => BigInt(/u(\d+)/.exec(v)?.[1] ?? -1);
const zeroAdapter = (tag) => check(`adapter holds 0 STX / 0 canex / 0 aiearn @${tag}`, S(tag).as === 0n && S(tag).ac === 0n && S(tag).aa === 0n, JSON.stringify(S(tag), (_, x) => String(x)));

console.log("\n--- balance deltas ---");
// buy-curve
check(`buy-curve: fee recipient +${fee1(CA)} (1%)`, D("c0", "c1", "rs") === fee1(CA), D("c0", "c1", "rs"));
check(`buy-curve: user paid exactly ${CA}`, -D("c0", "c1", "us") === CA, -D("c0", "c1", "us"));
check("buy-curve: user tokens += returned out == quote", D("c0", "c1", "uc") === U(cap.c_out) && U(cap.c_out) === U(cap.cq), `${D("c0", "c1", "uc")} out ${cap.c_out} q ${cap.cq}`);
check("buy-curve: failed u5004 call moved nothing, exact-min call paid fee once", D("c1", "c2", "rs") === fee1(CA) && -D("c1", "c2", "us") === CA, `${D("c1", "c2", "rs")} / ${D("c1", "c2", "us")}`);
// buy-pool
check(`buy-pool: fee recipient +${fee1(BA)} (1%)`, D("b0", "b1", "rs") === fee1(BA), D("b0", "b1", "rs"));
check(`buy-pool: user paid exactly ${BA}`, -D("b0", "b1", "us") === BA, -D("b0", "b1", "us"));
check(`buy-pool: user tokens += out == off-chain dy ${BDY}`, D("b0", "b1", "ua") === U(cap.b_out) && U(cap.b_out) === BDY, `${D("b0", "b1", "ua")} out ${cap.b_out}`);
check("buy-pool: failed slippage call moved nothing", D("b1", "b2", "us") === 0n && D("b1", "b2", "rs") === 0n && D("b1", "b2", "ua") === 0n, JSON.stringify([D("b1", "b2", "us"), D("b1", "b2", "ua")].map(String)));
// sell-pool
const sNet = U(cap.s_out), sFee = D("s0", "s1", "rs");
check(`sell-pool: user tokens -= ${SA}`, -D("s0", "s1", "ua") === SA, -D("s0", "s1", "ua"));
check(`sell-pool: user STX += returned net ${sNet}`, D("s0", "s1", "us") === sNet, D("s0", "s1", "us"));
check("sell-pool: fee == 1% of gross (net + fee)", sFee > 0n && sFee === fee1(sNet + sFee), `fee ${sFee} net ${sNet}`);
check("sell-pool: failed u5004 call moved nothing", D("s1", "s2", "us") === 0n && D("s1", "s2", "rs") === 0n && D("s1", "s2", "ua") === 0n, JSON.stringify([D("s1", "s2", "us"), D("s1", "s2", "ua")].map(String)));
check(`sell-pool: exact-min call sold ${SB}, paid fee`, -D("s2", "s3", "ua") === SB && D("s2", "s3", "rs") > 0n, `${D("s2", "s3", "ua")} fee ${D("s2", "s3", "rs")}`);
check("unapproved sell-pool reverted the Bitflow swap too", D("u0", "u1", "ua") === 0n && D("u0", "u1", "us") === 0n, `${D("u0", "u1", "ua")}`);
// recipient == user
check("recipient==user buy-curve: user paid only net (keeps fee), no failure", -D("w0", "w1", "us") === CA - fee1(CA) && D("w0", "w1", "uc") > 0n, -D("w0", "w1", "us"));
check("recipient==user buy-pool: user paid only net (keeps fee)", -D("w1", "w2", "us") === BA - fee1(BA) && D("w1", "w2", "ua") > 0n, -D("w1", "w2", "us"));
check("recipient==user sell-pool: user STX += gross (net + kept fee)", (() => { const g = D("w2", "w3", "us"), n = U(cap.w_sell); return g - n === fee1(g) && g > n; })(), `${D("w2", "w3", "us")} vs ${cap.w_sell}`);
check("recipient==user: FEE_R unchanged across all three", D("w0", "w3", "rs") === 0n, D("w0", "w3", "rs"));
// adapter residue
for (const t of ["c0", "c1", "c2", "b1", "b2", "s1", "s2", "s3", "u1", "w1", "w2", "w3", "final"]) zeroAdapter(t);

console.log(`\nbuy-pool just-above-min result: ${cap.b_slip}`);
console.log(`sell-pool tokens-in u0 result: ${cap.s_zero}`);
console.log(`\n=== ${pass}/${pass + fail} PASS${fail ? `, ${fail} FAIL` : ""} ===\nSession: ${sid}\nView: ${url}`);
process.exit(fail ? 1 : 0);
