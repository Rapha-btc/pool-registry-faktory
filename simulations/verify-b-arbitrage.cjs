// verify-b-arbitrage.cjs
// stxer mainnet-fork sim for the DRAFT b-arbitrage-faktory-v3 (Clarity 5).
// Deploys as SPV9K21 so DEPLOYER = chavita, then:
//   - sBTC whale pumps the fak pool (buy B) -> B rich on fak
//   - run the two forward routes; assert profit, actual == check-* estimate,
//     and that the profit lands at DEPLOYER (chavita), NOT at SAINT
//   - wrong-direction route -> ERR-NO-PROFIT (u1001)
//   - rescue: stranger u1002, deployer ok
//   - conservation: contract holds 0 B / sBTC / STX; SAINT balance unchanged
//
// Run: NODE_PATH=/home/raphastacks/projects/mia-single-faktory/node_modules \
//      node simulations/verify-b-arbitrage.cjs
const fs = require("fs");
const path = require("path");
const { uintCV, someCV, bufferCV, deserializeCV, cvToString } = require("@stacks/transactions");
const { SimulationBuilder, getSimulationResult } = require("stxer");

const DEPLOYER = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22";
const SBTC_WHALE = "SP2C7BCAP2NH3EYWCCVHJ6K0DMZBXDFKQ56KR7QN2";
const STRANGER = "SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM";
const B = `${DEPLOYER}.b-faktory`;
const B_POOL = `${DEPLOYER}.b-faktory-pool`;
const SBTC = "SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token";
const SAINT = "SM2JTZ2DHHQFS6J3KVFTPCV72MCN0C03J2ZH6K039";
const ARB = `${DEPLOYER}.b-arbitrage-faktory-v3`;

const PUMP_SATS = 5_000_000n;      // 0.05 BTC buys B -> B rich on fak
const ARB_IN = 5_000_000_000_000n; // 50k B (8-dec)

const SRC = fs.readFileSync(path.join(__dirname, "..", "contracts", "b-arbitrage-faktory-v3.clar"), "utf8");
const plan = [];
const b = SimulationBuilder.new({ stacksNodeAPI: "http://77.42.3.101/stacks-api" });
function call(label, sender, cid, fn, args, expect, capture) {
  b.withSender(sender).addContractCall({ contract_id: cid, function_name: fn, function_args: args });
  plan.push({ kind: "tx", label, expect, capture });
}
function evalc(label, code, capture) { b.addEvalCode(B_POOL, code); plan.push({ kind: "eval", label, capture }); }

b.withSender(DEPLOYER).addContractDeploy({ contract_name: "b-arbitrage-faktory-v3", source_code: SRC, clarity_version: 5 });
plan.push({ kind: "tx", label: "deploy b-arbitrage-faktory-v3 (Clarity 5)", expect: /^\(ok / });

evalc("DEPLOYER B before", `(contract-call? '${B} get-balance '${DEPLOYER})`, "depB0");
evalc("SAINT B before", `(contract-call? '${B} get-balance '${SAINT})`, "saint0");
evalc("reserves baseline", `(contract-call? '${B_POOL} get-reserves-quote)`, "res0");

// pump fak: buy B with sBTC -> B rich on fak
call("whale pumps fak (buy B w/ 5M sats)", SBTC_WHALE, B_POOL, "execute",
  [uintCV(PUMP_SATS), someCV(bufferCV(Uint8Array.from([0])))], /^\(ok /);

evalc("check-fak-bit-alex(50k B)", `(contract-call? '${ARB} check-fak-bit-alex u${ARB_IN})`, "chk1");
call("arb-fak-bit-alex(50k B) -> ok", DEPLOYER, ARB, "arb-fak-bit-alex", [uintCV(ARB_IN), uintCV(1n)], /^\(ok /, "arb1");
call("whale pumps fak again (5M sats)", SBTC_WHALE, B_POOL, "execute",
  [uintCV(PUMP_SATS), someCV(bufferCV(Uint8Array.from([0])))], /^\(ok /);
evalc("check-fak-vel-alex(50k B)", `(contract-call? '${ARB} check-fak-vel-alex u${ARB_IN})`, "chk2");
call("arb-fak-vel-alex(50k B) -> ok", DEPLOYER, ARB, "arb-fak-vel-alex", [uintCV(ARB_IN), uintCV(1n)], /^\(ok /, "arb2");

// wrong direction now (fak still rich) -> reverse route unprofitable
call("arb-alex-bit-fak(50k B) -> err u1001", DEPLOYER, ARB, "arb-alex-bit-fak", [uintCV(ARB_IN), uintCV(1n)], "(err u1001)");
// slippage guard
call("arb-fak-bit-alex huge min-out -> err u1000", DEPLOYER, ARB, "arb-fak-bit-alex",
  [uintCV(ARB_IN), uintCV(999999999999999n)], "(err u1000)");
// rescue auth
call("stranger rescue-b -> err u1002", STRANGER, ARB, "rescue-b", [uintCV(1n)], "(err u1002)");

evalc("DEPLOYER B after", `(contract-call? '${B} get-balance '${DEPLOYER})`, "depB1");
evalc("SAINT B after (unchanged)", `(contract-call? '${B} get-balance '${SAINT})`, "saint1");
evalc("contract B left (0)", `(contract-call? '${B} get-balance '${ARB})`, "cB");
evalc("contract sBTC left (0)", `(contract-call? '${SBTC} get-balance '${ARB})`, "cSbtc");
evalc("contract STX left (0)", `(stx-get-balance '${ARB})`, "cStx");

function decodeTx(s){const r=s?.Result?.Transaction; if(!r)return{ok:false,str:"<none>"}; if("Err"in r)return{ok:false,str:`ENGINE-ERR ${JSON.stringify(r.Err).slice(0,150)}`}; try{return{ok:true,str:cvToString(deserializeCV(r.Ok.result))}}catch(e){return{ok:false,str:`decode-fail ${e.message}`}}}
function decodeEval(s){const r=s?.Result?.Eval; if(!r)return"<none>"; if(!("Ok"in r))return`ERR ${JSON.stringify(r.Err).slice(0,150)}`; try{return cvToString(deserializeCV(r.Ok))}catch{return String(r.Ok)}}
const num=(s,k)=>BigInt((String(s).match(new RegExp(`\\(${k} u(\\d+)\\)`))||[])[1]??"-1");
const bare=(s)=>BigInt((String(s).match(/u(\d+)/)||[])[1]??"-1");

(async()=>{
  const sid=await b.run(); const url=`https://stxer.xyz/simulations/mainnet/${sid}`;
  console.log(`\nView: ${url}\n`);
  const res=await getSimulationResult(sid); const cap={}; let pass=0,fail=0;
  res.steps.forEach((s,i)=>{const p=plan[i]; if(!p)return;
    if(p.kind==="tx"){const d=decodeTx(s); if(p.capture)cap[p.capture]=d.str;
      const ok=p.expect instanceof RegExp?p.expect.test(d.str):d.str===p.expect;
      console.log(`${ok?"OK  ":"FAIL"} [${i}] ${p.label}  ${d.str.slice(0,90)}`); ok?pass++:fail++;
    } else {const v=decodeEval(s); if(p.capture)cap[p.capture]=v; console.log(`ii   [${i}] ${p.label}: ${String(v).slice(0,90)}`);}
  });
  const check=(l,ok,got)=>{ok?pass++:fail++; console.log(`${ok?"OK  ":"FAIL"} ${l}${ok?"":"  got "+got}`);};
  const p1=num(cap.arb1,"token-out")-ARB_IN, p2=num(cap.arb2,"token-out")-ARB_IN;
  check("route1 profit > 0", p1>0n, p1);
  check("route1 actual == check estimate", num(cap.arb1,"token-out")===num(cap.chk1,"token-out"), `${num(cap.arb1,"token-out")} vs ${num(cap.chk1,"token-out")}`);
  check("route2 profit > 0", p2>0n, p2);
  check("route2 actual == check estimate", num(cap.arb2,"token-out")===num(cap.chk2,"token-out"), `${num(cap.arb2,"token-out")} vs ${num(cap.chk2,"token-out")}`);
  check("DEPLOYER received both outputs (profit to chavita)", bare(cap.depB1)-bare(cap.depB0)===p1+p2, `${bare(cap.depB1)-bare(cap.depB0)} vs ${p1+p2}`);
  check("SAINT balance UNCHANGED (no leak to multisig)", bare(cap.saint1)===bare(cap.saint0), `${bare(cap.saint0)} -> ${bare(cap.saint1)}`);
  check("contract holds 0 B", bare(cap.cB)===0n, cap.cB);
  check("contract holds 0 sBTC", bare(cap.cSbtc)===0n, cap.cSbtc);
  check("contract holds 0 STX", bare(cap.cStx)===0n, cap.cStx);
  console.log(`\n=== ${pass} passed, ${fail} failed ===\nView: ${url}`);
  if(fail>0)process.exit(1);
})().catch(e=>{console.error(e);process.exit(1)});
