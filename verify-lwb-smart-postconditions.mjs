// verify-lwb-smart-postconditions.mjs
// Deny-mode post-condition proof for lwb-smart-faktory (not yet deployed): the
// router is deployed inside the session as a raw tx, then the FE-shaped smart
// buys/sells run with postConditionMode Deny and the PC list the FE will ship.
// Run: node verify-lwb-smart-postconditions.mjs
import fs from "node:fs";
import { Pc, PostConditionMode, makeUnsignedContractCall, makeUnsignedContractDeploy, uintCV, ClarityVersion } from "@stacks/transactions";
import { createSimulationSession, submitSimulationSteps, setSender } from "stxer";

const D = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22";
const ROUTER = `${D}.lwb-smart-faktory`;
const FAK_POOL = `${D}.lwb-faktory-pool`;
const TOKEN = "SP277HZA8AGXV42MZKDW5B2NNN61RHQ42MTAHVNB1.little-whiny-bitch-stxcity", ASSET = "LWB";
const XYK_LWB = "SP277HZA8AGXV42MZKDW5B2NNN61RHQ42MTAHVNB1.xyk-pool-stx-lwb-v-1-1";
const SBTC = "SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token";
const BITFLOW_POOL = "SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1";
const VELAR_POOL = "SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070";
const SBTC_HOLDER = "SP2C7BCAP2NH3EYWCCVHJ6K0DMZBXDFKQ56KR7QN2";
const STX_HOLDER = "SP9BP4PN74CNR5XT7CMAMBPA0GWC9HMB69HVVV51";
const LWB_HOLDER = "SPZ2X7Q0Z69KTN7SZF90MR9AZGZ2ETXFGMFXKKN8";
const API = process.env.STACKS_API || "http://77.42.3.101/stacks-api";
const src = fs.readFileSync(process.env.SRC || "./contracts/d-lwb-smart-faktory.clar", "utf8");

// dex senders on either flag: xyk-pool-stx-lwb pays LWB (buys) or STX (sells)
const dexPcs = () => [
  Pc.principal(XYK_LWB).willSendGte(0).ft(TOKEN, ASSET),
  Pc.principal(XYK_LWB).willSendGte(0).ustx(),
];
const bridgePcs = () => [
  Pc.principal(BITFLOW_POOL).willSendGte(0).ustx(),
  Pc.principal(BITFLOW_POOL).willSendGte(0).ft(SBTC, "sbtc-token"),
  Pc.principal(VELAR_POOL).willSendGte(0).ustx(),
  Pc.principal(VELAR_POOL).willSendGte(0).ft(SBTC, "sbtc-token"),
];
const buySbtc = (user, sats, minOut) => [
  Pc.principal(user).willSendEq(sats).ft(SBTC, "sbtc-token"),
  Pc.principal(ROUTER).willSendGte(minOut).ft(TOKEN, ASSET),
  Pc.principal(ROUTER).willSendEq(sats).ft(SBTC, "sbtc-token"),
  Pc.principal(ROUTER).willSendGte(0).ustx(),
  Pc.principal(FAK_POOL).willSendGte(0).ft(TOKEN, ASSET),
  ...dexPcs(), ...bridgePcs(),
];
const buyStx = (user, micro, minOut) => [
  Pc.principal(user).willSendEq(micro).ustx(),
  Pc.principal(ROUTER).willSendGte(minOut).ft(TOKEN, ASSET),
  Pc.principal(ROUTER).willSendEq(micro).ustx(),
  Pc.principal(ROUTER).willSendGte(0).ft(SBTC, "sbtc-token"),
  Pc.principal(FAK_POOL).willSendGte(0).ft(TOKEN, ASSET),
  ...dexPcs(), ...bridgePcs(),
];
const sellSbtc = (user, amt, minOut) => [
  Pc.principal(user).willSendEq(amt).ft(TOKEN, ASSET),
  Pc.principal(ROUTER).willSendEq(amt).ft(TOKEN, ASSET),
  Pc.principal(ROUTER).willSendGte(minOut).ft(SBTC, "sbtc-token"),
  Pc.principal(ROUTER).willSendGte(0).ustx(),
  Pc.principal(FAK_POOL).willSendGte(0).ft(SBTC, "sbtc-token"),
  ...dexPcs(), ...bridgePcs(),
];
const sellStx = (user, amt, minOut) => [
  Pc.principal(user).willSendEq(amt).ft(TOKEN, ASSET),
  Pc.principal(ROUTER).willSendEq(amt).ft(TOKEN, ASSET),
  Pc.principal(ROUTER).willSendGte(minOut).ustx(),
  Pc.principal(ROUTER).willSendGte(0).ft(SBTC, "sbtc-token"),
  Pc.principal(FAK_POOL).willSendGte(0).ft(SBTC, "sbtc-token"),
  ...dexPcs(), ...bridgePcs(),
];

async function nonceOf(addr) {
  const j = await (await fetch(`${API}/extended/v1/address/${addr}/nonces`)).json();
  return j.possible_next_nonce ?? j.last_executed_tx_nonce + 1;
}
const PUB = "02" + "11".repeat(32);
async function rawCall({ sender, nonce, fn, args, pcs }) {
  const tx = await makeUnsignedContractCall({ contractAddress: D, contractName: "lwb-smart-faktory", functionName: fn, functionArgs: args, network: "mainnet", publicKey: PUB, nonce, fee: 20000, postConditionMode: PostConditionMode.Deny, postConditions: pcs });
  return setSender(tx, sender).serialize();
}
async function rawDeploy(nonce) {
  const tx = await makeUnsignedContractDeploy({ contractName: "lwb-smart-faktory", codeBody: src, clarityVersion: ClarityVersion.Clarity5, network: "mainnet", publicKey: PUB, nonce, fee: 100000, postConditionMode: PostConditionMode.Allow });
  return setSender(tx, D).serialize();
}

const sid = await createSimulationSession({});
console.log("View: https://stxer.xyz/simulations/mainnet/" + sid + "\n");
const n = { [D]: await nonceOf(D), [SBTC_HOLDER]: await nonceOf(SBTC_HOLDER), [STX_HOLDER]: await nonceOf(STX_HOLDER), [LWB_HOLDER]: await nonceOf(LWB_HOLDER) };
const labels = [], txs = [];
txs.push({ Transaction: await rawDeploy(n[D]++) }); labels.push("deploy lwb-smart-faktory (Clarity 5, raw tx)");
const sats = 100000, micro = 100000000, lwb = 10000000000000;
// min-out 0: this harness proves PC completeness, not slippage (parity is in the negatives harness)
const plan = [
  ["smart-buy-with-sbtc", SBTC_HOLDER, [uintCV(sats), uintCV(0)], buySbtc(SBTC_HOLDER, sats, 0)],
  ["smart-buy-with-stx", STX_HOLDER, [uintCV(micro), uintCV(0)], buyStx(STX_HOLDER, micro, 0)],
  ["smart-sell-for-sbtc", LWB_HOLDER, [uintCV(lwb), uintCV(0)], sellSbtc(LWB_HOLDER, lwb, 0)],
  ["smart-sell-for-stx", LWB_HOLDER, [uintCV(lwb), uintCV(0)], sellStx(LWB_HOLDER, lwb, 0)],
];
// run twice so both bridges get exercised as the optimizer flips after the first trades
for (let round = 0; round < 2; round++) for (const [fn, sender, args, pcs] of plan) {
  txs.push({ Transaction: await rawCall({ sender, nonce: n[sender]++, fn, args, pcs }) });
  labels.push(`${fn} round ${round + 1} (${pcs.length} PCs, Deny)`);
}
const res = await submitSimulationSteps(sid, { steps: txs });
let fails = 0;
res.steps.forEach((step, i) => {
  const t = step?.Transaction;
  const rc = t && "Ok" in t ? t.Ok : null;
  const ok = !!rc && !rc.post_condition_aborted && !rc.vm_error && !String(rc.result).startsWith("(err") && !/^0x08/.test(String(rc.result));
  const summary = !t ? "<no tx>" : "Err" in t ? "ERR " + JSON.stringify(t.Err).slice(0, 160) : rc.post_condition_aborted ? "POST-CONDITION ABORT" : rc.vm_error ? "VM " + rc.vm_error : "ok " + String(rc.result).slice(0, 60);
  if (!ok) {
    fails++;
    const evs = (rc?.events || []).map((r) => (typeof r === "string" ? JSON.parse(r) : r));
    for (const e of evs) {
      if (e.stx_transfer_event) { const d = e.stx_transfer_event; console.log(`      STX ${d.sender.slice(-24)} -> ${d.recipient.slice(-28)} ${d.amount}`); }
      if (e.ft_transfer_event) { const d = e.ft_transfer_event; console.log(`      FT  ${d.sender.slice(-24)} -> ${d.recipient.slice(-28)} ${d.asset_identifier.split("::")[1]} ${d.amount}`); }
    }
  }
  console.log(`  ${ok ? "ok  " : "FAIL"} ${labels[i]}: ${summary}`);
});
console.log(`\n${labels.length - fails}/${labels.length} deny-mode txs clean`);
if (fails) process.exit(1);
