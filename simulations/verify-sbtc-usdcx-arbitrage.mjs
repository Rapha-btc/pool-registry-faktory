// stxer mainnet-fork check of contracts/sbtc-usdcx-arbitrage-faktory.clar on the
// LIVE swap-router-sbtc-usdcx-jing-v5-5 (Jing book markets-sbtc-usdcx-jing-v6-4
// + Bitflow DLMM sbtc-usdcx pools 1/2/17). Keyless: the Lazer update comes from
// the faktory-dao backend (GET /api/auction/pyth-lazer-update?pair=sbtc-usdcx).
//   R roles: keeper / admin hand-over, old admin locked out
//   A refusals on live state: non-keeper, bad shares, bad split, xyk/velar
//     unreachable, DLMM round trip with no edge -> u1001, nothing moves
//   B planted gaps (resting Jing makers at mid +/-10 bps, a whale pushes DLMM
//     pool 1 off mid): arb-usdcx and arb-sbtc both profit, inventory grows
//   D withdraws: keeper / stranger refused, multisig empties the contract
// Run: node simulations/verify-sbtc-usdcx-arbitrage.mjs
//   (SRC=<file> to test other bytes, H=<height> to pin, JING_HARNESS=<dir> for
//    the jing-contracts-v3/simulations folder)
import fs from 'node:fs';
import { uintCV, noneCV, someCV, bufferCV, tupleCV, stringAsciiCV, deserializeCV } from '@stacks/transactions';
import { SimulationBuilder } from 'stxer';
const HD = process.env.JING_HARNESS ?? new URL('../../../../jing-contracts-v3/simulations/', import.meta.url).href;
const { NODE, DEP, SBTC, WHALE, P_, mk, S, retry, sleep, check, must, show, call, tx, evalIn, deploy, summary, Stop, plain } =
  await import(new URL('_yg-loop-common.js', HD.endsWith('/') ? HD : HD + '/').href);
const { lazerFeedTimes } = await import(new URL('_lazer.js', HD.endsWith('/') ? HD : HD + '/').href);

const SRC = fs.readFileSync(process.env.SRC ?? new URL('../contracts/sbtc-usdcx-arbitrage-faktory.clar', import.meta.url), 'utf8');
const NAME = 'sbtc-usdcx-arbitrage-faktory', ARB = `${DEP}.${NAME}`;
const RT = `${DEP}.swap-router-sbtc-usdcx-jing-v5-5`, MKT = `${DEP}.markets-sbtc-usdcx-jing-v6-4`;
const USDCX = 'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx';
const USDC_WHALE = 'SP13JV946AF23WA94SVANA8D6VRTTYEWCJJ8Q5YMJ';
const POOL_1 = 'SM1FKXGNZJWSTWDWXQZJNF7B5TV5ZB235JTCXYXKD.dlmm-pool-sbtc-usdcx-v-1-bps-10';
const OTHER = mk(812), KEEP = mk(813), MS = mk(814);
const BPS = 10_000n, SCALE = 10_000_000_000n;
const TX = P_(SBTC), TY = P_(USDCX), AX = stringAsciiCV('sbtc-token'), AY = stringAsciiCV('usdcx-token');

// ---------- Lazer (feeds 1 / 7), strictly newer than the sim block time ----------
let U = null;
async function fetchUsdcx() {
  const r = await fetch('https://faktory-dao-backend.vercel.app/api/auction/pyth-lazer-update?pair=sbtc-usdcx', { headers: { 'x-api-key': process.env.FAKTORY_API_KEY || 'jc_e4d2e10396eef95215a7afd492f42d743a3325739d29200c2a28b256f778be01' } });
  if (!r.ok) throw new Error(`backend lazer ${r.status}`);
  const d = (await r.json()).data;
  if (String(d.feedIds) !== '1,7') throw new Error(`feeds ${d.feedIds}`);
  return { hex: d.hex.replace(/^0x/, ''), px: BigInt(d.priceX), py: BigInt(d.priceY) };
}
async function fresh() {
  const bt = Number(await evalIn(MKT, 'stacks-block-time'));
  for (let i = 0; i < 40; i++) {
    const u = await retry(fetchUsdcx); const t = await retry(() => lazerFeedTimes(u.hex, [1, 7]));
    if (t.at > bt) { U = { ...u, mid: u.px * 100000000n / u.py }; return U; }
    await sleep(3000);
  }
  throw new Error('no fresh [1,7] update');
}
const upd = () => bufferCV(Buffer.from(U.hex, 'hex'));

// ---------- balances ----------
const bal = async (tok, who) => (await evalIn(tok, `(get-balance '${who})`)).ok;
const held = async (who = ARB) => ({ sb: await bal(SBTC, who), us: await bal(USDCX, who) });
const group = (g) => { S.group = g; console.log(`\n=== ${g} ===`); };
const L = (o) => tupleCV({ jing: uintCV(o.jing ?? 0n), dlmm: uintCV(o.dlmm ?? 0n) });
const results = [];
// the router's swap prints in a receipt (topic swap-*), as legs
const legs = (receipt) => (receipt?.events ?? []).map((e) => typeof e === 'string' ? JSON.parse(e) : e)
  .filter((e) => e.committed !== false && e.contract_event)
  .map((e) => { try { return plain(deserializeCV(e.contract_event.raw_value)); } catch { return null; } })
  .filter((p) => p && typeof p.topic === 'string' && p.topic.startsWith('swap-'))
  .map((p) => `${p.topic}: jing ${p['jing-in']}->${p['jing-out']} dlmm ${p['dlmm-in']}->${p['dlmm-out']} unsold ${p.unsold} out ${p.out}`);

// one arb call; checks profit on ok, "nothing moved" on err
async function arb(label, { fromUsdcx, amount, leg1, shares, bps = 150n, minProfit = 0n, sender = KEEP, want }) {
  await fresh();
  const up = U.mid * (BPS + bps) / BPS, dn = U.mid * (BPS - bps) / BPS;
  // limit = worst price per leg: buying sBTC caps it (up), selling floors it (dn)
  const [l1, l2] = fromUsdcx ? [up, dn] : [dn, up];
  const fn = fromUsdcx ? 'arb-usdcx' : 'arb-sbtc';
  const h0 = await held(), r0 = await held(RT);
  const r = await tx(label, sender, ARB, fn, [uintCV(amount), L(leg1), L(shares), uintCV(l1), uintCV(l2), someCV(upd()), uintCV(minProfit)], want ?? ((v) => v?.ok !== undefined || v?.err !== undefined));
  const h1 = await held(), r1 = await held(RT);
  let profit = null;
  if (r.res?.ok !== undefined) {
    check(`${label}: returns (ok true)`, r.res.ok === true, show(r.res));
    profit = fromUsdcx ? h1.us - h0.us : h1.sb - h0.sb;
    for (const l of legs(r.receipt)) console.log(`     ${l}`);
    console.log(`     profit ${profit} ${fromUsdcx ? 'micro-USDCx' : 'sats'} (inventory ${show(h0)} -> ${show(h1)})`);
    check(`${label}: profit >= min-profit and > 0`, profit >= minProfit && profit > 0n, String(profit));
    check(`${label}: other asset did not shrink`, (fromUsdcx ? h1.sb - h0.sb : h1.us - h0.us) >= 0n, show({ h0, h1 }));
  } else {
    check(`${label}: revert moved nothing`, h1.sb === h0.sb && h1.us === h0.us, show({ h0, h1 }));
  }
  check(`${label}: router keeps nothing`, r1.sb === r0.sb && r1.us === r0.us, show({ r0, r1 }));
  results.push({ label, result: show(r.res ?? r.vm).slice(0, 60), profit });
  return { r, profit };
}

// whale moves DLMM through the router, DLMM-only (no update needed)
async function dlmmPush(label, sellSbtc, who, amount) {
  const amts = tupleCV({ dlmm: uintCV(amount), xyk: uintCV(0), velar: uintCV(0) });
  const mins = tupleCV({ dlmm: uintCV(1), xyk: uintCV(0), velar: uintCV(0) });
  const fn = sellSbtc ? 'swap-sbtc-for-usdcx' : 'swap-usdcx-for-sbtc';
  const r = await tx(label, who, RT, fn, [uintCV(amount), uintCV(0), uintCV(1), noneCV(), noneCV(), amts, mins, uintCV(1)], (v) => v?.ok?.['dlmm-in'] > 0n);
  const o = r.res?.ok ?? {};
  await fresh();
  const p = sellSbtc ? o['dlmm-out'] * SCALE / o['dlmm-in'] : o['dlmm-in'] * SCALE / o['dlmm-out'];
  console.log(`     dlmm ${o['dlmm-in']} -> ${o['dlmm-out']} (avg ${Number((p - U.mid) * BPS / U.mid)} bps vs mid ${U.mid}), unsold ${o.unsold}`);
  return o;
}

// a maker resting on the Jing book (settles a pending deposit if the market parks it)
async function rest(label, side, who, amount, price) {
  const fn = side === 'x' ? 'deposit-token-x' : 'deposit-token-y';
  const [t, a] = side === 'x' ? [TX, AX] : [TY, AY];
  await tx(label, who, MKT, fn, [uintCV(amount), uintCV(price), noneCV(), t, a], (v) => v?.ok !== undefined);
  await fresh();
  const pend = side === 'x' ? 'get-token-x-pending-deposit' : 'get-token-y-pending-deposit';
  if (await evalIn(MKT, `(${pend} '${who})`)) await tx(`${label}: settle pending`, DEP, MKT, `settle-token-${side}-deposit`, [P_(who), upd(), t, a], (v) => v?.ok !== undefined);
  const cyc = await evalIn(MKT, '(get-current-cycle)');
  const dep = await evalIn(MKT, `(get-token-${side}-deposit u${cyc} '${who})`);
  must(`${label}: resting ${dep}`, dep === amount, String(dep));
}

try {
  const b = SimulationBuilder.new({ stacksNodeAPI: NODE });
  if (process.env.H) b.useBlockHeight(Number(process.env.H));
  b.withSender(DEP).addEvalCode(SBTC, '(get-total-supply)');
  S.sid = await retry(() => b.run());
  console.log(`View: https://stxer.xyz/simulations/mainnet/${S.sid}`);

  group('setup');
  await deploy(DEP, NAME, SRC);
  console.log(`  whales: sBTC ${await bal(SBTC, WHALE.x)} sats, USDCx ${await bal(USDCX, USDC_WHALE)}; pool-1 ${show(await held(POOL_1))}`);
  must('fund ARB 0.05 sBTC', (await call(WHALE.x, SBTC, 'transfer', [uintCV(5_000_000n), P_(WHALE.x), P_(ARB), noneCV()])).res?.ok === true);
  must('fund ARB 5,000 USDCx', (await call(USDC_WHALE, USDCX, 'transfer', [uintCV(5_000_000_000n), P_(USDC_WHALE), P_(ARB), noneCV()])).res?.ok === true);
  const start = await held();
  check('inventory funded', start.sb === 5_000_000n && start.us === 5_000_000_000n, show(start));
  check('roles start at the deployer', show(await evalIn(ARB, '(get-roles)')) === show({ admin: DEP, keeper: DEP }), show(await evalIn(ARB, '(get-roles)')));

  group('R roles');
  await tx('R1 keeper cannot set keeper before handover', KEEP, ARB, 'set-keeper', [P_(KEEP)], { err: 1002n });
  await tx('R2 admin sets keeper', DEP, ARB, 'set-keeper', [P_(KEEP)], { ok: true });
  await tx('R3 admin hands admin to the multisig', DEP, ARB, 'set-admin', [P_(MS)], { ok: true });
  await tx('R4 old admin is out', DEP, ARB, 'set-keeper', [P_(DEP)], { err: 1002n });
  await tx('R5 keeper cannot set admin', KEEP, ARB, 'set-admin', [P_(KEEP)], { err: 1002n });
  check('R6 roles = multisig admin, keeper wallet', show(await evalIn(ARB, '(get-roles)')) === show({ admin: MS, keeper: KEEP }), show(await evalIn(ARB, '(get-roles)')));

  group('A refusals (live state)');
  const S1 = 200_000_000n; // 200 USDCx
  await arb('A1 non-keeper refused (old deployer)', { fromUsdcx: true, amount: S1, leg1: { dlmm: S1 }, shares: { dlmm: 10000n }, sender: DEP, want: { err: 1002n } });
  await arb('A2 non-keeper refused (stranger, sBTC side)', { fromUsdcx: false, amount: 100_000n, leg1: { dlmm: 100_000n }, shares: { dlmm: 10000n }, sender: OTHER, want: { err: 1002n } });
  await arb('A3 leg-2 shares != 10000 -> u1011', { fromUsdcx: true, amount: S1, leg1: { dlmm: S1 }, shares: { dlmm: 9000n }, want: { err: 1011n } });
  await arb('A4 leg-1 split != amount -> router u3004', { fromUsdcx: true, amount: S1, leg1: { dlmm: S1 - 1n }, shares: { dlmm: 10000n }, want: { err: 3004n } });
  await arb('A5 leg-1 split > amount -> router u3004', { fromUsdcx: false, amount: 100_000n, leg1: { jing: 1n, dlmm: 100_000n }, shares: { dlmm: 10000n }, want: { err: 3004n } });
  // xyk / velar: the arb's tuples have no such keys, so a 4-key leg is refused before any code runs
  {
    await fresh();
    const V4 = tupleCV({ jing: uintCV(0), dlmm: uintCV(0), xyk: uintCV(S1), velar: uintCV(0) });
    const h0 = await held();
    let r; try { r = await call(KEEP, ARB, 'arb-usdcx', [uintCV(S1), V4, L({ dlmm: 10000n }), uintCV(1), uintCV(1), someCV(upd()), uintCV(0)]); } catch (e) { r = { thrown: String(e.message ?? e).slice(0, 200) }; }
    const h1 = await held();
    check('A6 xyk leg (4-key tuple) refused: tx rejected, no (ok)', r.res?.ok === undefined, show({ res: r.res, vm: r.vm, thrown: r.thrown }));
    check('A6 nothing moved', h1.sb === h0.sb && h1.us === h0.us, show({ h0, h1 }));
    // and the router itself refuses a nonzero xyk / velar amount, so no other path exists
    const amts = (x, v) => tupleCV({ dlmm: uintCV(0), xyk: uintCV(x), velar: uintCV(v) });
    const z = tupleCV({ dlmm: uintCV(0), xyk: uintCV(0), velar: uintCV(0) });
    await tx('A7 router: xyk amount -> u3003', KEEP, RT, 'swap-usdcx-for-sbtc', [uintCV(S1), uintCV(0), uintCV(1), noneCV(), noneCV(), amts(S1, 0), z, uintCV(0)], { err: 3003n });
    await tx('A8 router: velar amount -> u3003', KEEP, RT, 'swap-sbtc-for-usdcx', [uintCV(10_000n), uintCV(0), uintCV(1), noneCV(), noneCV(), amts(0, 10_000), z, uintCV(0)], { err: 3003n });
  }
  await arb('A9 live DLMM -> DLMM (no edge) -> u1001', { fromUsdcx: true, amount: S1, leg1: { dlmm: S1 }, shares: { dlmm: 10000n }, want: { err: 1001n } });
  await arb('A10 live DLMM -> DLMM sBTC side (no edge) -> u1001', { fromUsdcx: false, amount: 200_000n, leg1: { dlmm: 200_000n }, shares: { dlmm: 10000n }, want: { err: 1001n } });
  await tx('A11 keeper cannot withdraw USDCx', KEEP, ARB, 'withdraw-usdcx', [uintCV(1n)], { err: 1002n });
  await tx('A12 keeper cannot withdraw sBTC', KEEP, ARB, 'withdraw-sbtc', [uintCV(1n)], { err: 1002n });
  await tx('A13 stranger cannot withdraw USDCx', OTHER, ARB, 'withdraw-usdcx', [uintCV(1n)], { err: 1002n });
  await tx('A14 old deployer cannot withdraw sBTC', DEP, ARB, 'withdraw-sbtc', [uintCV(1n)], { err: 1002n });

  group('B planted gaps');
  await fresh();
  // resting makers on the Jing book: an sBTC ask at mid+10 bps, a USDCx bid at mid-10 bps
  await rest('B0a x maker rests 0.01 sBTC at mid+10bps', 'x', WHALE.x, 1_000_000n, U.mid * (BPS + 10n) / BPS);
  await rest('B0b y maker rests 2,000 USDCx at mid-10bps', 'y', USDC_WHALE, 2_000_000_000n, U.mid * (BPS - 10n) / BPS);
  // the arb with the book still at fair: DLMM -> Jing has no edge yet
  await arb('B1 before the gap: DLMM -> Jing no edge -> u1001', { fromUsdcx: true, amount: S1, leg1: { dlmm: S1 }, shares: { jing: 10000n }, want: { err: 1001n } });
  // gap 1: whale dumps sBTC into DLMM pool 1 -> sBTC cheap on DLMM
  await dlmmPush('B2 whale dumps 0.6 sBTC into DLMM', true, WHALE.x, 60_000_000n);
  await arb('B3 arb-usdcx 500: buy DLMM, sell Jing', { fromUsdcx: true, amount: 500_000_000n, leg1: { dlmm: 500_000_000n }, shares: { jing: 10000n }, want: (v) => v?.ok === true });
  // leg 2 split 80 Jing / 20 DLMM (split-by-shares, rounding to dlmm): still profits
  await arb('B4 arb-usdcx 400: buy DLMM, sell 80 Jing / 20 DLMM', { fromUsdcx: true, amount: 400_000_000n, leg1: { dlmm: 400_000_000n }, shares: { jing: 8000n, dlmm: 2000n }, want: (v) => v?.ok === true });
  // all of leg 2 back into the same pool gives the edge back: the guard reverts it
  await arb('B4a arb-usdcx 400 with leg 2 back into DLMM -> u1001', { fromUsdcx: true, amount: 400_000_000n, leg1: { dlmm: 400_000_000n }, shares: { dlmm: 10000n }, want: { err: 1001n } });
  await arb('B4b arb-usdcx 400 second trip: buy DLMM, sell Jing', { fromUsdcx: true, amount: 400_000_000n, leg1: { dlmm: 400_000_000n }, shares: { jing: 10000n }, want: (v) => v?.ok === true });
  await arb('B5 arb-usdcx min-profit unreachable -> u1001', { fromUsdcx: true, amount: 300_000_000n, leg1: { dlmm: 300_000_000n }, shares: { jing: 10000n }, minProfit: 1_000_000_000n, want: { err: 1001n } });
  // gap 2: whale buys sBTC hard on DLMM -> sBTC dear on DLMM
  await dlmmPush('B6 whale buys sBTC with 100,000 USDCx on DLMM', false, USDC_WHALE, 100_000_000_000n);
  await arb('B7 arb-sbtc 0.003: sell DLMM, buy Jing', { fromUsdcx: false, amount: 300_000n, leg1: { dlmm: 300_000n }, shares: { jing: 10000n }, want: (v) => v?.ok === true });
  await arb('B8 arb-sbtc 0.002 second trip: sell DLMM, buy Jing', { fromUsdcx: false, amount: 200_000n, leg1: { dlmm: 200_000n }, shares: { jing: 10000n }, want: (v) => v?.ok === true });
  await arb('B9 arb-sbtc min-profit unreachable -> u1001', { fromUsdcx: false, amount: 200_000n, leg1: { dlmm: 200_000n }, shares: { jing: 10000n }, minProfit: 1_000_000n, want: { err: 1001n } });
  await arb('B10 arb-sbtc by a non-keeper while the gap is open -> u1002', { fromUsdcx: false, amount: 200_000n, leg1: { dlmm: 200_000n }, shares: { jing: 10000n }, sender: OTHER, want: { err: 1002n } });
  const end = await held();
  check('B11 inventory grew in both assets', end.us >= start.us && end.sb >= start.sb && (end.us > start.us || end.sb > start.sb), show({ start, end }));

  group('D withdraws');
  await tx('D1 multisig withdraws all USDCx', MS, ARB, 'withdraw-usdcx', [uintCV(end.us)], { ok: true });
  await tx('D2 multisig withdraws all sBTC', MS, ARB, 'withdraw-sbtc', [uintCV(end.sb)], { ok: true });
  const z = await held();
  check('D3 contract empty', z.sb === 0n && z.us === 0n, show(z));
  check('D4 multisig holds the inventory', show(await held(MS)) === show(end), show(await held(MS)));
  console.log(`\ninventory: ${start.us} -> ${end.us} micro-USDCx, ${start.sb} -> ${end.sb} sats`);
  console.log('summary:'); for (const r of results) console.log(`  ${r.label.padEnd(58)} ${r.result}${r.profit != null ? `  profit ${r.profit}` : ''}`);
} catch (e) {
  if (!(e instanceof Stop)) { console.error(e); S.fails.push(`EXC ${e.message}`); }
}
summary();
