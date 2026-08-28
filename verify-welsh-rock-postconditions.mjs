// verify-welsh-rock-postconditions.mjs
// Deny-mode post-condition proof for the DEPLOYED welsh-smart-faktory and
// rock-smart-faktory routers: FE-shaped smart buys/sells with the exact PC
// list the FE ships (SMART_TOKENS dexSenders + shared bridge senders).
// Run: node verify-welsh-rock-postconditions.mjs welsh|rock
import { Pc, PostConditionMode, makeUnsignedContractCall, uintCV } from "@stacks/transactions";
import { createSimulationSession, submitSimulationSteps, setSender } from "stxer";

const which = process.argv[2] || "welsh";
const D = "SPV9K21TBFAK4KNRJXF5DFP8N7W46G4V9RCJDC22";
const SBTC = "SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token";
const BITFLOW_POOL = "SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1";
const VELAR_POOL = "SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-pool-v1_0_0-0070";
const ALEX_VAULT = "SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-vault-v2-01";
const ALEX_FT = ["SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex", "alex"];
const WCORGI_FT = ["SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wcorgi", "wcorgi"];
const VELAR_CORE = "SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-core";
const SBTC_HOLDER = "SP2C7BCAP2NH3EYWCCVHJ6K0DMZBXDFKQ56KR7QN2";
const STX_HOLDER = "SP9BP4PN74CNR5XT7CMAMBPA0GWC9HMB69HVVV51";
const API = process.env.STACKS_API || "http://77.42.3.101/stacks-api";

const CFG = {
  welsh: {
    name: "welsh-smart-faktory", fakPool: `${D}.welshcorgicoin-faktory-pool-v2`,
    token: "SP3NE50GEXFG9SZGTT51P40X2CKYSZ5CC4ZTZ7A2G.welshcorgicoin-token", asset: "welshcorgicoin",
    holder: "SP3AP6DRSQ6P4FETB5M33D082Q2ABGJW60MT6103Q", sell: 10_000_000_000n, // 10k WELSH
    // dexSenders as the FE will ship them (bitflow + velar lists merged)
    dex: (T, A) => [
      Pc.principal("SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-welsh-stx-v-1-1").willSendGte(0).ft(T, A),
      Pc.principal("SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-welsh-stx-v-1-1").willSendGte(0).ustx(),
      // ALEX 2-hop: the vault pays WELSH (buys) or STX (sells) and the
      // intermediate `alex` bounces vault -> router -> vault. wcorgi never
      // moves (proven on the fork: the vault pays welshcorgicoin directly).
      Pc.principal(ALEX_VAULT).willSendGte(0).ft(T, A),
      Pc.principal(ALEX_VAULT).willSendGte(0).ustx(),
      Pc.principal(ALEX_VAULT).willSendGte(0).ft(...ALEX_FT),
      Pc.principal(`${D}.welsh-smart-faktory`).willSendGte(0).ft(...ALEX_FT),
    ],
  },
  rock: {
    name: "rock-smart-faktory", fakPool: `${D}.rock-faktory-pool-2`,
    token: "SP4M2C88EE8RQZPYTC4PZ88CE16YGP825EYF6KBQ.stacks-rock", asset: "rock",
    holder: "SP1J9JVDWMAM63RZM54R43TK84XCT85C2W254TMYX", sell: 100_000_000_000_000n, // 100M ROCK (thin pools; 5k ROCK yields 0 sats -> u1003)
    dex: (T, A) => [
      Pc.principal(VELAR_CORE).willSendGte(0).ft(T, A),
      Pc.principal(VELAR_CORE).willSendGte(0).ustx(),
    ],
  },
}[which];
const ROUTER = `${D}.${CFG.name}`, FAK_POOL = CFG.fakPool, TOKEN = CFG.token, ASSET = CFG.asset, HOLDER = CFG.holder;

const dexPcs = () => CFG.dex(TOKEN, ASSET);
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
  const tx = await makeUnsignedContractCall({ contractAddress: D, contractName: CFG.name, functionName: fn, functionArgs: args, network: "mainnet", publicKey: PUB, nonce, fee: 20000, postConditionMode: PostConditionMode.Deny, postConditions: pcs });
  return setSender(tx, sender).serialize();
}

const sid = await createSimulationSession({});
console.log(`[${which}] View: https://stxer.xyz/simulations/mainnet/${sid}\n`);
const n = { [SBTC_HOLDER]: await nonceOf(SBTC_HOLDER), [STX_HOLDER]: await nonceOf(STX_HOLDER), [HOLDER]: await nonceOf(HOLDER) };
const labels = [], txs = [];
const sats = 100000, micro = 100000000, amt = CFG.sell;
const plan = [
  ["smart-buy-with-sbtc", SBTC_HOLDER, [uintCV(sats), uintCV(0)], buySbtc(SBTC_HOLDER, sats, 0)],
  ["smart-buy-with-stx", STX_HOLDER, [uintCV(micro), uintCV(0)], buyStx(STX_HOLDER, micro, 0)],
  ["smart-sell-for-sbtc", HOLDER, [uintCV(amt), uintCV(0)], sellSbtc(HOLDER, amt, 0)],
  ["smart-sell-for-stx", HOLDER, [uintCV(amt), uintCV(0)], sellStx(HOLDER, amt, 0)],
];
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
    if (process.env.DUMP) console.log('      RAW ' + JSON.stringify(rc ?? t).slice(0, 1500));
    const evs = (rc?.events || []).map((r) => (typeof r === "string" ? JSON.parse(r) : r));
    for (const e of evs) {
      if (e.stx_transfer_event) { const d = e.stx_transfer_event; console.log(`      STX ${d.sender.slice(-28)} -> ${d.recipient.slice(-28)} ${d.amount}`); }
      if (e.ft_transfer_event) { const d = e.ft_transfer_event; console.log(`      FT  ${d.sender.slice(-28)} -> ${d.recipient.slice(-28)} ${d.asset_identifier.split("::")[1]} ${d.amount}`); }
    }
  }
  console.log(`  ${ok ? "ok  " : "FAIL"} ${labels[i]}: ${summary}`);
});
console.log(`\n[${which}] ${labels.length - fails}/${labels.length} deny-mode txs clean`);
if (fails) process.exit(1);
