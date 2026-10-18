// stxer mainnet-fork check of contracts/stx-sbtc-arbitrage-faktory.clar (router v5-5).
// Run: node simulations/verify-stx-sbtc-arbitrage.mjs   (SRC=<file> to test other bytes, H=<height> to pin)
import fs from 'node:fs';
import { ClarityVersion, uintCV, someCV, tupleCV } from '@stacks/transactions';
import { SimulationBuilder, getSimulationResult } from 'stxer';
// Reuses the stxer harness from jing-contracts-v3 (checked out next to fakfun
// under ~/projects); JING_HARNESS overrides its path.
const { H, NODE, SBTC, VELAR_POOL, WHALE_X, check, retry, evRaw, tx, fund, mk, fields, uint, principal, update, printsOf, printAfter, cv, done } =
  await import(process.env.JING_HARNESS ?? new URL('../../../../jing-contracts-v3/simulations/_router-v5-3-harness.js', import.meta.url).href);
process.env.ROUTER_RENEW_TENURE = '1';
const SRC = fs.readFileSync(new URL(process.env.SRC ? `file://${process.env.SRC}` : '../contracts/stx-sbtc-arbitrage-faktory.clar', import.meta.url), 'utf8');
const OP = mk(811), OTHER = mk(812), KEEP = mk(813), MS = mk(814);
const ARB = `${OP}.stx-sbtc-arbitrage-faktory`;
const bal = (p) => `{ x: (unwrap-panic (contract-call? '${SBTC} get-balance '${p})), y: (stx-get-balance '${p}) }`;
const held = async () => { const f = fields(await evRaw(ARB, bal(ARB))); return { x: f.x, y: f.y }; };
const clock = async () => Number(uint(await evRaw(ARB, 'stacks-block-time')));
const V = (o) => tupleCV({ jing: uintCV(o.jing ?? 0n), dlmm: uintCV(o.dlmm ?? 0n), xyk: uintCV(o.xyk ?? 0n), velar: uintCV(o.velar ?? 0n) });
const results = [];
async function arb(label, { fromStx, amount, leg1, shares, smart = false, bps = 150n, minProfit = 0n, sender = KEEP, want }) {
  const u = await printAfter(await clock());
  const up = u.mid * (10_000n + bps) / 10_000n, dn = u.mid * (10_000n - bps) / 10_000n;
  const [l1, l2] = fromStx ? [up, dn] : [dn, up];
  const fn = `arb-${fromStx ? 'stx' : 'sbtc'}${smart ? '-smart' : ''}`;
  const args = smart ? [uintCV(amount), uintCV(l1), uintCV(l2), someCV(update(u)), uintCV(u.mid), uintCV(minProfit)]
                     : [uintCV(amount), V(leg1), V(shares), uintCV(l1), uintCV(l2), someCV(update(u)), uintCV(minProfit)];
  const h0 = await held();
  const r = await tx(label, sender, ARB, fn, args, want ?? ((v) => /^\((ok|err) /.test(v)));
  const h1 = await held();
  if (r.result.startsWith('(ok')) {
    check(`${label}: returns (ok true)`, r.result, '(ok true)');
    const p = fromStx ? h1.y - h0.y : h1.x - h0.x;
    console.log(`     profit ${p} ${fromStx ? 'uSTX' : 'sats'}`);
    check(`${label}: profit >= min-profit`, p >= minProfit, true);
    check(`${label}: other asset did not shrink`, (fromStx ? h1.x - h0.x : h1.y - h0.y) >= 0n, true);
  } else {
    check(`${label}: revert moved nothing`, h1.x === h0.x && h1.y === h0.y, true);
    check(`${label}: revert committed no event`, printsOf(r).length, 0);
  }
  results.push({ label, result: r.result.slice(0, 80) });
  return r;
}
async function main() {
  const b = SimulationBuilder.new({ stacksNodeAPI: NODE });
  if (process.env.H) b.useBlockHeight(Number(process.env.H));
  b.withSender(OP).addContractDeploy({ contract_name: 'stx-sbtc-arbitrage-faktory', source_code: SRC, clarity_version: ClarityVersion.Clarity5 });
  H.sid = await retry(() => b.run());
  console.log(`View: https://stxer.xyz/simulations/mainnet/${H.sid}`);
  const setup = await retry(() => getSimulationResult(H.sid));
  const d = setup.steps.find((s) => s.Result?.Transaction)?.Result.Transaction.Ok;
  check('deploy', d && !d.vm_error ? cv(d.result) : JSON.stringify(setup.steps[0]?.Result).slice(0, 600), '(ok true)');
  await fund('y', OP, 1_000_000_000n);
  await fund('y', ARB, 5_000_000_000n);    // 5,000 STX inventory
  await fund('x', ARB, 2_000_000n);        // 0.02 BTC inventory
  check('inventory funded', JSON.stringify((await held()), (k, v) => typeof v === 'bigint' ? v.toString() : v), '{"x":"2000000","y":"5000000000"}');
  await fund('y', KEEP, 100_000_000n); await fund('y', MS, 100_000_000n);
  await tx('R1 keeper cannot set keeper before handover', KEEP, ARB, 'set-keeper', [principal(KEEP)], '(err u1002)');
  await tx('R2 admin sets keeper', OP, ARB, 'set-keeper', [principal(KEEP)], '(ok true)');
  await tx('R3 admin hands admin to the multisig', OP, ARB, 'set-admin', [principal(MS)], '(ok true)');
  await tx('R4 old admin is out', OP, ARB, 'set-keeper', [principal(OP)], '(err u1002)');
  const S = 200_000_000n;
  await arb('A1 non-keeper refused (old deployer)', { fromStx: true, amount: S, leg1: { xyk: S }, shares: { velar: 10000n }, sender: OP, want: '(err u1002)' });
  await arb('A2 shares != 10000', { fromStx: true, amount: S, leg1: { xyk: S }, shares: { velar: 9000n }, want: '(err u1011)' });
  await arb('A3 leg1 split != amount', { fromStx: true, amount: S, leg1: { xyk: S - 1n }, shares: { velar: 10000n }, want: '(err u3004)' });
  await arb('A4 live xyk->velar (no edge)', { fromStx: true, amount: S, leg1: { xyk: S }, shares: { velar: 10000n } });
  await arb('A5 live jing->velar', { fromStx: true, amount: S, leg1: { jing: S }, shares: { velar: 10000n } });
  await tx('B0 whale dumps 0.05 sBTC into Velar', WHALE_X, VELAR_POOL, 'swap', [principal(SBTC), principal('SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx'), principal('SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.univ2-fees-v1_0_0-0070'), uintCV(5_000_000n), uintCV(1)], (v) => v.startsWith('(ok'));
  await arb('B1 stx 600: buy velar, sell jing', { fromStx: true, amount: 600_000_000n, leg1: { velar: 600_000_000n }, shares: { jing: 10000n }, want: (v) => v.startsWith('(ok') });
  await arb('B2 stx 1000: buy velar, sell xyk 50 / dlmm 50', { fromStx: true, amount: 1_000_000_000n, leg1: { velar: 1_000_000_000n }, shares: { xyk: 5000n, dlmm: 5000n }, want: (v) => v.startsWith('(ok') });
  await arb('B3 min-profit unreachable', { fromStx: true, amount: 500_000_000n, leg1: { velar: 500_000_000n }, shares: { xyk: 10000n }, minProfit: 1_000_000_000n, want: '(err u1001)' });
  await arb('B4 sbtc 400k: sell jing, buy back velar', { fromStx: false, amount: 400_000n, leg1: { jing: 400_000n }, shares: { velar: 10000n } });
  const h = await held();
  await tx('D1 keeper cannot withdraw', KEEP, ARB, 'withdraw-stx', [uintCV(1n)], '(err u1002)');
  await tx('D2 multisig withdraws all STX', MS, ARB, 'withdraw-stx', [uintCV(h.y)], '(ok true)');
  await tx('D3 multisig withdraws all sBTC', MS, ARB, 'withdraw-sbtc', [uintCV(h.x)], '(ok true)');
  check('D4 contract empty', await evRaw(ARB, bal(ARB)), '(tuple (x u0) (y u0))');
  console.log(`\nfinal inventory before withdraw: ${h.y} uSTX (started 5000000000), ${h.x} sats (started 2000000)`);
  console.log('summary:'); for (const r of results) console.log(`  ${r.label.padEnd(48)} ${r.result}`);
  done();
}
main().catch((e) => { console.error(e); console.log(`${H.passed}/${H.checks} checks green`); console.log(`Sim: https://stxer.xyz/simulations/mainnet/${H.sid}`); process.exit(1); });
