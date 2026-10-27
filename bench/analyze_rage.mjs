// Standalone, dependency-free rage summaries and paired seed-block win intervals.
import { readFileSync } from "node:fs";

const args = process.argv.slice(2);
const paths = [];
const options = { case: "Stalker", banked: false, sources: false };
for (let i = 0; i < args.length; i++) {
  if (["--case", "--weapon", "--build"].includes(args[i])) {
    options[args[i].slice(2)] = args[++i];
  } else if (["--banked", "--sources"].includes(args[i])) {
    options[args[i].slice(2)] = true;
  } else if (args[i].startsWith("--")) {
    throw new Error(`Unknown option ${args[i]}`);
  } else {
    paths.push(args[i]);
  }
}
if (!paths.length) throw new Error("Usage: node bench/analyze_rage.mjs <result.json> [--case 4xL4] [--weapon DW] [--build 'WR partial'] [--banked] [--sources]");
const mean = values => values.reduce((sum, value) => sum + Number(value), 0) / Math.max(1, values.length);
const percent = (values, predicate) => 100 * mean(values.map(predicate));

function summarize(fights) {
  if (fights.some(f => f.rage_samples.length !== f.turns)) {
    throw new Error("Rage observations do not cover every combat turn");
  }
  const turns = fights.flatMap(f => f.rage_samples);
  const decisions = fights.flatMap(f => f.rage_decisions);
  const execute = fights.map(f => f.spending.Execute ?? {});
  const casts = execute.reduce((sum, row) => sum + (row.casts ?? 0), 0);
  return [percent(fights, f => f.win), mean(fights.map(f => f.hp)),
    mean(fights.map(f => f.turns)), mean(turns), percent(turns, r => r < 15),
    mean(fights.map(f => f.cap_loss)), mean(fights.map(f => f.rage_paid)),
    percent(decisions, d => d.first_blocked), percent(decisions, d => d.blocked > 0),
    percent(decisions, d => d.ready > 0 && d.affordable === 0), casts / fights.length,
    100 * execute.reduce((sum, row) => sum + (row.free ?? 0), 0) / Math.max(1, casts)];
}

function pairedInterval(control, candidate) {
  if (control.length !== candidate.length) throw new Error("Unpaired cell lengths");
  const seeds = new Map();
  for (let i = 0; i < control.length; i++) {
    if (control[i].seed !== candidate[i].seed) throw new Error("Unpaired seeds");
    const values = seeds.get(control[i].seed) ?? [];
    values.push(100 * (Number(candidate[i].win) - Number(control[i].win)));
    seeds.set(control[i].seed, values);
  }
  const blocks = [...seeds.values()].map(mean);
  let state = 713;
  const random = () => ((state = (Math.imul(state, 1664525) + 1013904223) >>> 0) / 2 ** 32);
  const draws = Array.from({ length: 2000 }, () =>
    mean(blocks.map(() => blocks[Math.floor(random() * blocks.length)]))).sort((a, b) => a - b);
  return [mean(blocks), draws[49], draws[1949]];
}

const groups = new Map();
let policy;
const cells = new Set();
for (const path of paths) {
  const data = JSON.parse(readFileSync(path, "utf8").replace(/^\uFEFF/, ""));
  if (policy && policy !== data.setup.policy) throw new Error("Analyze policies separately");
  policy = data.setup.policy;
  for (const row of data.rows) {
    if (row.case !== options.case || row.banked !== options.banked) continue;
    if (options.weapon && row.weapon !== options.weapon) continue;
    if (options.build && row.build !== options.build) continue;
    const key = `${row.build}/${row.variant}`;
    const cell = `${key}/${row.weapon}`;
    if (cells.has(cell)) throw new Error(`Duplicate cell ${cell}`);
    cells.add(cell);
    groups.set(key, [...(groups.get(key) ?? []), ...row.fights]);
  }
}
if (!groups.size) throw new Error("No matching cells");
console.log(`${options.case}; banked=${options.banked}; weapon=${options.weapon ?? "equal pooled"}; policy=${policy}`);
console.log("Build/variant                      Win%     HP  Turns   Rage   Low%    Cap   Paid   Top%   Any%   Dry%   Exec  Free%");
for (const [key, fights] of groups) {
  console.log(key.padEnd(33) + summarize(fights).map(n => n.toFixed(1).padStart(7)).join(""));
  if (options.sources) {
    const sources = {};
    const spending = {};
    for (const fight of fights) {
      for (const [source, value] of Object.entries(fight.rage_sources)) {
        sources[source] = (sources[source] ?? 0) + value / fights.length;
      }
      for (const [skill, row] of Object.entries(fight.spending)) {
        spending[skill] ??= {};
        for (const [label, value] of Object.entries(row)) {
          spending[skill][label] = (spending[skill][label] ?? 0) + value / fights.length;
        }
      }
    }
    console.log("  accepted sources:", JSON.stringify(sources));
    console.log("  spending:", JSON.stringify(spending));
  }
  if (!key.endsWith("/live")) {
    const baseline = groups.get(key.slice(0, key.lastIndexOf("/")) + "/live");
    const [delta, low, high] = pairedInterval(baseline, fights);
    console.log(`  win delta ${delta.toFixed(1)}pp; exploratory 95% seed-block bootstrap [${low.toFixed(1)}, ${high.toFixed(1)}]`);
  }
}
console.log("Top/Any: decisions with first/any otherwise-valid option blocked by rage. Dry: valid options exist, none affordable. Low: turns below 15 rage. Cap/Paid: mean total rage per fight. Free%: free Execute casts.");
