// verify-smart-postconditions.mjs
// Proves the front ends' post-condition lists are COMPLETE for the deployed
// pepe-smart-faktory and flatearth-smart-faktory routers. The FE submits
// smart buys with postConditionMode Deny, so any asset sender missing from the
// list aborts the tx. This builds the same txs the FE builds (same PCs, Deny)
// as raw unsigned transactions and runs them on a mainnet fork.
//
// Run: node verify-smart-postconditions.mjs
import {
  Pc, PostConditionMode, makeUnsignedContractCall, uintCV, cvToHex, hexToCV, cvToJSON,
} from "@stacks/transactions";
import { createSimulationSession, submitSimulationSteps, setSender } from "stxer";

const D = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22";
const SBTC = "SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token";
const BITFLOW_POOL = "SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1";
const VELAR_POOL = "SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070";
const BITFLOW_PEPE_POOL = "SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-pepe-stx-v-1-1";
const VELAR_CORE = "SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-core";
const VELAR_FLAT_POOL = "SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-pool-v1_0_0-0003";
const SBTC_HOLDER = "SP2C7BCAP2NH3EYWCCVHJ6K0DMZBXDFKQ56KR7QN2";
const STX_HOLDER = "SP9BP4PN74CNR5XT7CMAMBPA0GWC9HMB69HVVV51";
const HIRO = "https://api.hiro.so";

// Same table as faktory-dao PoolTradingPanel SMART_TOKENS / legacy smartRouting.ts
const TOKENS = {
  PEPE: {
    router: `${D}.pepe-smart-faktory`, fakPool: `${D}.pepe-faktory-pool-v2-2`,
    token: "SP1Z92MPDQEWZXW36VX71Q25HKF5K2EPCJ304F275.tokensoft-token-v4k68639zxz", asset: "tokensoft-token",
    dexSenders: { bitflow: [{ principal: BITFLOW_PEPE_POOL, token: true }], velar: [{ principal: VELAR_CORE, token: true, ustx: true }] },
  },
  FlatEarth: {
    router: `${D}.flatearth-smart-faktory`, fakPool: `${D}.flatearth-faktory-pool-v2`,
    token: "SP3W69VDG9VTZNG7NTW1QNCC1W45SNY98W1JSZBJH.flat-earth-stxcity", asset: "FlatEarth",
    dexSenders: { bitflow: [{ principal: VELAR_FLAT_POOL, token: true, ustx: true }], velar: [{ principal: VELAR_FLAT_POOL, token: true, ustx: true }] },
  },
};

// Both families, always: the router re-decides the bridge at execution time,
// so a list built from an off-chain compare-* can be stale. Gte 0 is harmless.
const dexPcs = (c, _route) => [...c.dexSenders.bitflow, ...c.dexSenders.velar].flatMap((d) => [
  ...(d.token ? [Pc.principal(d.principal).willSendGte(0).ft(c.token, c.asset)] : []),
  ...(d.ustx ? [Pc.principal(d.principal).willSendGte(0).ustx()] : []),
]);
const sbtcPcs = (c, user, sats, minOut, route) => [
  Pc.principal(user).willSendEq(sats).ft(SBTC, "sbtc-token"),
  Pc.principal(c.router).willSendGte(minOut).ft(c.token, c.asset),
  Pc.principal(c.router).willSendEq(sats).ft(SBTC, "sbtc-token"),
  Pc.principal(c.fakPool).willSendGte(0).ft(c.token, c.asset),
  ...dexPcs(c, route),
  Pc.principal(BITFLOW_POOL).willSendGte(0).ustx(),
  Pc.principal(VELAR_POOL).willSendGte(0).ustx(),
  Pc.principal(VELAR_POOL).willSendGte(0).ft(SBTC, "sbtc-token"),
  Pc.principal(c.router).willSendGte(0).ustx(),
];
const stxPcs = (c, user, micro, minOut, route) => [
  Pc.principal(user).willSendEq(micro).ustx(),
  Pc.principal(c.router).willSendGte(minOut).ft(c.token, c.asset),
  Pc.principal(c.router).willSendEq(micro).ustx(),
  Pc.principal(c.router).willSendGte(0).ft(SBTC, "sbtc-token"),
  Pc.principal(c.fakPool).willSendGte(0).ft(c.token, c.asset),
  ...dexPcs(c, route),
  Pc.principal(BITFLOW_POOL).willSendGte(0).ft(SBTC, "sbtc-token"),
  Pc.principal(VELAR_POOL).willSendGte(0).ft(SBTC, "sbtc-token"),
  Pc.principal(VELAR_POOL).willSendGte(0).ustx(),
];

async function readOnly(contract, fn, args, sender) {
  const [a, n] = contract.split(".");
  const r = await fetch(`${HIRO}/v2/contracts/call-read/${a}/${n}/${fn}`, {
    method: "POST", headers: { "content-type": "application/json" },
    body: JSON.stringify({ sender, arguments: args.map(cvToHex) }),
  });
  const j = await r.json();
  if (!j.okay) throw new Error(`read-only ${fn} failed: ${JSON.stringify(j)}`);
  return cvToJSON(hexToCV(j.result));
}
async function nonceOf(addr) {
  const j = await (await fetch(`${HIRO}/extended/v1/address/${addr}/nonces`)).json();
  return j.possible_next_nonce ?? j.last_executed_tx_nonce + 1;
}
// Same bytes the wallet would sign, minus the signature (the simulator derives
// tx-sender from the patched signer field). Dummy pubkey is fine for that.
async function rawTx({ sender, nonce, contract, fn, args, pcs }) {
  const tx = await makeUnsignedContractCall({
    contractAddress: contract.split(".")[0], contractName: contract.split(".")[1],
    functionName: fn, functionArgs: args, network: "mainnet",
    publicKey: "02" + "11".repeat(32), nonce, fee: 20000,
    postConditionMode: PostConditionMode.Deny, postConditions: pcs,
  });
  return setSender(tx, sender).serialize();
}

const sid = await createSimulationSession({});
console.log("View: https://stxer.xyz/simulations/mainnet/" + sid + "\n");
const labels = [];
const txs = [];
const nonces = { [SBTC_HOLDER]: await nonceOf(SBTC_HOLDER), [STX_HOLDER]: await nonceOf(STX_HOLDER) };
for (const [sym, c] of Object.entries(TOKENS)) {
  const sats = 100000, micro = 100000000;
  const rS = await readOnly(c.router, "compare-sbtc-to-token-routes", [uintCV(sats)], SBTC_HOLDER);
  const rT = await readOnly(c.router, "compare-stx-to-token-routes", [uintCV(micro)], STX_HOLDER);
  const routeS = rS.value["best-route"].value, routeT = rT.value["best-route"].value;
  // min-out: 90% of the router's own estimate, like the FE's slippage floor
  const minS = Math.floor(Number(rS.value["best-output"].value) * 0.9);
  const minT = Math.floor(Number(rT.value["best-output"].value) * 0.9);
  const pS = sbtcPcs(c, SBTC_HOLDER, sats, minS, routeS);
  const pT = stxPcs(c, STX_HOLDER, micro, minT, routeT);
  txs.push({ Transaction: await rawTx({ sender: SBTC_HOLDER, nonce: nonces[SBTC_HOLDER]++, contract: c.router, fn: "smart-buy-with-sbtc", args: [uintCV(sats), uintCV(minS)], pcs: pS }) });
  labels.push(`${sym} smart-buy-with-sbtc (route ${routeS}, ${pS.length} PCs, Deny)`);
  txs.push({ Transaction: await rawTx({ sender: STX_HOLDER, nonce: nonces[STX_HOLDER]++, contract: c.router, fn: "smart-buy-with-stx", args: [uintCV(micro), uintCV(minT)], pcs: pT }) });
  labels.push(`${sym} smart-buy-with-stx (route ${routeT}, ${pT.length} PCs, Deny)`);
}
const res = await submitSimulationSteps(sid, { steps: txs });
let fails = 0;
res.steps.forEach((step, i) => {
  const t = step?.Transaction;
  const rc = t && "Ok" in t ? t.Ok : null;
  const ok = !!rc && !rc.post_condition_aborted && !rc.vm_error;
  const summary = !t ? "<no tx>" : "Err" in t ? "ERR " + String(t.Err).slice(0, 160)
    : rc.post_condition_aborted ? "POST-CONDITION ABORT" : rc.vm_error ? "VM " + rc.vm_error : "ok " + String(rc.result).slice(0, 40);
  if (!ok) {
    fails++;
    if (rc) {
      console.log("      receipt keys:", Object.keys(rc).join(","), "| vm_error:", rc.vm_error);
      const evs = (rc.events || []).map((r) => (typeof r === "string" ? JSON.parse(r) : r));
      for (const e of evs) {
        if (e.stx_transfer_event) { const d = e.stx_transfer_event; console.log(`      STX ${d.sender.slice(-24)} -> ${d.recipient.slice(-28)} ${d.amount}`); }
        if (e.ft_transfer_event) { const d = e.ft_transfer_event; console.log(`      FT  ${d.sender.slice(-24)} -> ${d.recipient.slice(-28)} ${d.asset_identifier.split("::")[1]} ${d.amount}`); }
      }
    }
  }
  console.log(`  ${ok ? "ok  " : "FAIL"} ${labels[i]}: ${summary}`);
});
console.log(`\n${labels.length - fails}/${labels.length} deny-mode buys clean`);
if (fails) process.exit(1);
