"""Summarize Stalker trials with paired, seed-blocked uncertainty (stdlib only)."""

import argparse
import csv
import functools
import json
import math
import statistics
from pathlib import Path


def beta_fraction(a, b, x):
    qab, qap, qam = a + b, a + 1, a - 1
    c, d = 1.0, 1 - qab * x / qap
    d = 1 / max(d, 1e-300)
    h = d
    for m in range(1, 301):
        m2 = 2 * m
        for aa in (m * (b - m) * x / ((qam + m2) * (a + m2)),
                   -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2))):
            d = 1 + aa * d
            c = 1 + aa / c
            if abs(d) < 1e-300:
                d = 1e-300
            if abs(c) < 1e-300:
                c = 1e-300
            d = 1 / d
            delta = d * c
            h *= delta
        if abs(delta - 1) < 3e-14:
            return h
    raise ArithmeticError("Incomplete beta did not converge")


def beta_regularized(x, a, b):
    if x <= 0:
        return 0.0
    if x >= 1:
        return 1.0
    factor = math.exp(math.lgamma(a + b) - math.lgamma(a) - math.lgamma(b)
                      + a * math.log(x) + b * math.log1p(-x))
    if x < (a + 1) / (a + b + 2):
        return factor * beta_fraction(a, b, x) / a
    return 1 - factor * beta_fraction(b, a, 1 - x) / b


def t_two_sided(value, df):
    return beta_regularized(df / (df + value * value), df / 2, 0.5)


@functools.lru_cache(maxsize=None)
def t_critical(df):
    lo, hi = 0.0, 20.0
    for _ in range(65):
        mid = (lo + hi) / 2
        if t_two_sided(mid, df) > 0.05:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


def estimate(values):
    count = len(values)
    mean = statistics.mean(values)
    se = statistics.stdev(values) / math.sqrt(count) if count > 1 else 0.0
    half = t_critical(count - 1) * se if count > 1 else 0.0
    p = t_two_sided(abs(mean / se), count - 1) if se else float(mean == 0)
    return dict(mean=mean, low=mean - half, high=mean + half, p=p, seeds=count)


def win_estimate(values):
    # Wilson-style bounds with n independent seed blocks, including 0/100% cases.
    # Pooled blocks can be fractional; use the bounded-outcome binomial variance
    # envelope rather than treating every reused-seed stratum as independent.
    count = len(values)
    proportion = statistics.mean(values) / 100
    z = 1.959963984540054
    denominator = 1 + z * z / count
    center = (proportion + z * z / (2 * count)) / denominator
    half = z * math.sqrt(proportion * (1 - proportion) / count
                         + z * z / (4 * count * count)) / denominator
    return dict(mean=100 * proportion, low=100 * max(0, center - half),
                high=100 * min(1, center + half))


def metrics(fight):
    return dict(boss_damage=600 - fight["enemy_hp"],
                healing=fight["healing_total"],
                class_healing=fight["healing_total"] - fight["healing"].get("Potion", 0)
                - fight["healing"].get("Out-of-combat regeneration", 0),
                damage_taken=fight["damage_taken"], raw_damage_taken=fight["raw_damage_taken"],
                turns=fight["turns"], damage_per_turn=(600 - fight["enemy_hp"]) / fight["turns"],
                win_percent=100 * int(fight["win"]), end_hp=fight["hp"])


def key(row):
    return row["build"], row["weapon"], row["prepared"]


def blocked(cells, metric):
    """Average strata within seed first: six shared seeds are not six independent fights."""
    seeds = sorted(set.intersection(*(set(f["seed"] for f in c["fights"]) for c in cells)))
    maps = [{f["seed"]: metrics(f)[metric] for f in c["fights"]} for c in cells]
    return {s: statistics.mean(m[s] for m in maps) for s in seeds}


def write_csv(path, rows):
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("results", type=Path, nargs="+")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    rows, setups, replayed = [], [], 0
    for path in args.results:
        result = json.loads(path.read_text(encoding="utf-8-sig"))
        setups.append(result["setup"])
        rows.extend(result["rows"])
        replayed += result["replayed"]
    assert len({key(r) for r in rows if r["phase"] == "baseline"}) == 90
    baselines = {key(r): r for r in rows if r["phase"] == "baseline"}
    metric_names = list(metrics(rows[0]["fights"][0]))
    baseline_summary, baseline_cells, damage_sources = [], [], []
    for build in dict.fromkeys(r["build"] for r in baselines.values()):
        cells = [r for r in baselines.values() if r["build"] == build]
        assert len(cells) == 6
        record = dict(build=build)
        for name in metric_names:
            values = list(blocked(cells, name).values())
            result = win_estimate(values) if name == "win_percent" else estimate(values)
            for field in ("mean", "low", "high"):
                record[name + "_" + field] = result[field]
        baseline_summary.append(record)
    for cell in baselines.values():
        record = dict(build=cell["build"], weapon=cell["weapon"],
                      prepared=cell["prepared"], policy=cell["policy"], runs=cell["runs"])
        for name in metric_names:
            values = [metrics(f)[name] for f in cell["fights"]]
            result = win_estimate(values) if name == "win_percent" else estimate(values)
            for field in ("mean", "low", "high"):
                record[name + "_" + field] = result[field]
        for source in ("Spirit Hunt", "Victory Rush", "Potion", "Out-of-combat regeneration"):
            record["heal_" + source] = statistics.mean(f["healing"].get(source, 0)
                                                       for f in cell["fights"])
        baseline_cells.append(record)
        sources = sorted({source for f in cell["fights"] for source in f["damage"]})
        for source in sources:
            damage_sources.append(dict(build=cell["build"], weapon=cell["weapon"],
                                       prepared=cell["prepared"], source=source,
                                       mean_damage=statistics.mean(
                                           f["damage"].get(source, {}).get("effective", 0)
                                           for f in cell["fights"])))

    groups = {}
    ablation_cells = []
    for cell in rows:
        if cell["phase"] != "ablation":
            continue
        assert len(cell["disabled"]) == 1
        group = (cell["disabled"][0], cell["removed"], cell["build"])
        groups.setdefault(group, []).append(cell)
        base = baselines[key(cell)]
        assert cell["policy"] == base["policy"]
        record = dict(passive=cell["removed"], build=cell["build"],
                      weapon=cell["weapon"], prepared=cell["prepared"], runs=cell["runs"])
        for name in metric_names:
            full, removed = blocked([base], name), blocked([cell], name)
            # All deltas use FULL minus REMOVED, including healing/taken/turns.
            result = estimate([full[s] - removed[s] for s in removed])
            for field in ("mean", "low", "high", "p"):
                record[name + "_" + field] = result[field]
        ablation_cells.append(record)

    ablations, hypotheses = [], []
    primary = {"boss_damage", "damage_taken", "healing", "turns", "win_percent", "damage_per_turn"}
    for (skill_id, title, build), cells in groups.items():
        record = dict(id=skill_id, passive=title, build=build, strata=len(cells),
                      seeds=cells[0]["runs"])
        base_cells = [baselines[key(c)] for c in cells]
        for name in metric_names:
            full, removed = blocked(base_cells, name), blocked(cells, name)
            result = estimate([full[s] - removed[s] for s in removed])
            record[name + "_full"] = statistics.mean(full[s] for s in removed)
            record[name + "_removed"] = statistics.mean(removed.values())
            for field in ("mean", "low", "high", "p"):
                record[name + "_" + field] = result[field]
            if name in primary:
                hypotheses.append((result["p"], record, name))
        identical = 0
        total = 0
        for cell in cells:
            full_fights = {f["seed"]: f for f in baselines[key(cell)]["fights"]}
            for fight in cell["fights"]:
                total += 1
                full = full_fights[fight["seed"]]
                if all(full[k] == fight[k] for k in ("hp", "enemy_hp", "turns", "rage",
                                                    "combat_random", "healing_total",
                                                    "damage_taken", "damage")):
                    identical += 1
        record["identical_fights"] = identical
        record["paired_fights"] = total
        ablations.append(record)
    # One global Holm family: every tested passive/context and six main outcomes.
    previous = 0.0
    for index, (p, record, name) in enumerate(sorted(hypotheses, key=lambda h: h[0])):
        adjusted = min(1.0, max(previous, p * (len(hypotheses) - index)))
        record[name + "_holm_p"] = adjusted
        previous = adjusted
    write_csv(args.output / "baseline.csv", baseline_summary)
    write_csv(args.output / "baseline_cells.csv", baseline_cells)
    write_csv(args.output / "damage_sources.csv", damage_sources)
    write_csv(args.output / "passives.csv", ablations)
    write_csv(args.output / "passive_cells.csv", ablation_cells)
    native = {r["id"]: r for r in ablations if r["build"] != "All"}
    summary = []
    for row in ablations:
        if row["build"] != "All":
            continue
        own = native[row["id"]]
        record = dict(passive=row["passive"], native_kit=own["build"],
                      weapon_scope="DW only" if row["strata"] == 2 else "All three weapons")
        for label, source, metric, sign in (
                ("native_added_boss_hp", own, "boss_damage", 1),
                ("all_added_damage_per_turn", row, "damage_per_turn", 1),
                ("all_prevented_player_hp_loss", row, "damage_taken", -1),
                ("all_added_effective_healing", row, "healing", 1)):
            low = source[metric + ("_low" if sign == 1 else "_high")] * sign
            high = source[metric + ("_high" if sign == 1 else "_low")] * sign
            record[label] = round(sign * source[metric + "_mean"], 3)
            record[label + "_95ci"] = "[%.3f, %.3f]" % (low, high)
            record[label + "_holm_p"] = source[metric + "_holm_p"]
        summary.append(record)
    write_csv(args.output / "passive_summary.csv", summary)
    # Save an analysis manifest, not a validation report.
    manifest = dict(inputs=[str(p) for p in args.results],
                    entry_note="Prepared rage is set to 90 before resolving maintenance buffs; known Battle Shout adds 10, so Warrior-containing builds start at 100. Earlier result setup prose says 90 without this distinction; simulation behavior is identical.",
                    fights=sum(len(r["fights"]) for r in rows),
                    baseline_fights=sum(len(r["fights"]) for r in baselines.values()),
                    plain_replays=replayed, tested_passives=len({r["id"] for r in ablations}),
                    hypotheses=len(hypotheses),
                    method="Equal-weight weapon/entry strata; pair by seed and average strata within seed. Approximate paired Student-t 95% effect CIs; baseline win rates use Wilson-style bounds with independent seed blocks as n (binomial variance envelope for pooled fractional blocks). One global Holm correction over six primary outcomes and both kit contexts. Deltas are FULL minus REMOVED. Positive damage/healing/wins means more with passive; negative taken/turns means less with passive. Raw incoming damage, class-only healing and end HP exploratory, no corrected p. CIs are unadjusted; correlated RNG streams can diverge after removal. Effects conditional on fixed baseline-selected bot. Zero observed effect is not proof of no gameplay value.",
                    skipped=setups[0]["passives"])
    (args.output / "analysis.json").write_text(json.dumps(manifest, indent=2) + "\n",
                                              encoding="utf-8")
    print(json.dumps({k: v for k, v in manifest.items() if k not in ("method", "skipped")}, indent=2))


if __name__ == "__main__":
    main()
