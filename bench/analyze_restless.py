"""Paired Restless Blades summaries, with weapons averaged within seed blocks."""

import argparse
import collections
import json
import statistics

from analyze_stalker_passives import estimate


def values(row, fight):
    damage = row["initial_enemy_hp"] - fight["enemy_hp"]
    result = dict(win=100 * int(fight["win"]), damage=damage,
                  dpt=damage / fight["turns"], hp=fight["hp"], turns=fight["turns"],
                  taken=fight["raw_damage_taken"], healed=fight["healing_total"])
    for name in ["Mortal Strike", "Lava Burst", "Judgement", "Consecration",
                 "Eviscerate", "Divine Shield", "Evasion", "Feral Spirit", "Whirlwind"]:
        result[name] = fight["casts"].get(name, 0)
    for name in ["breath_releases", "breath_exposures", "dodge_actions", "dodge_cancelled_casts"]:
        if name in fight:
            result[name] = fight[name]
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+")
    parser.add_argument("--casts", action="store_true")
    args = parser.parse_args()
    cells = collections.defaultdict(dict)
    for path in args.paths:
        with open(path, encoding="utf-8-sig") as source:
            data = json.load(source)
        print("Run: {} cells, {} samples, {} replays".format(
            len(data["rows"]), data["setup"]["samples"], data["replayed"]))
        if "breath_response" in data["setup"]:
            print("Stalker breath response: " + data["setup"]["breath_response"])
        for row in data["rows"]:
            key = row["case"], row["quality"], row["weapon"]
            assert row["restless"] not in cells[key], "Duplicate comparison cell"
            cells[key][row["restless"]] = row
    groups = collections.defaultdict(list)
    print("With/without Restless: win%, end HP, damage/turn, fight turns, taken, healed")
    for key, pair in sorted(cells.items()):
        assert set(pair) == {True, False}
        maps = {enabled: {f["seed"]: values(row, f) for f in row["fights"]}
                for enabled, row in pair.items()}
        assert maps[True].keys() == maps[False].keys()
        groups[key[:2]].append(maps)
        fields = ["win", "hp", "dpt", "turns", "taken", "healed"]
        means = {enabled: {metric: statistics.mean(f[metric] for f in runs.values())
                           for metric in fields} for enabled, runs in maps.items()}
        print("{}: {}".format("/".join(key), ", ".join(
            "{} {:.2f}/{:.2f}".format(m, means[True][m], means[False][m]) for m in fields)))
    hypotheses = []
    for key, strata in sorted(groups.items()):
        seeds = sorted(strata[0][True])
        assert all(sorted(s[True]) == seeds for s in strata)
        print("POOLED {} ({} paired seed blocks):".format("/".join(key), len(seeds)))
        fields = ["win", "dpt", "hp", "damage", "taken", "healed", "turns"]
        if all("breath_exposures" in s[True][seeds[0]] for s in strata):
            fields += ["breath_releases", "breath_exposures", "dodge_actions", "dodge_cancelled_casts"]
        if args.casts:
            fields += ["Mortal Strike", "Lava Burst", "Judgement", "Consecration",
                       "Eviscerate", "Divine Shield", "Evasion", "Feral Spirit", "Whirlwind"]
        for metric in fields:
            blocks = {enabled: [statistics.mean(s[enabled][seed][metric] for s in strata)
                                for seed in seeds] for enabled in [True, False]}
            delta = [a - b for a, b in zip(blocks[True], blocks[False])]
            effect = estimate(delta)
            print("  {}: {:.3f}/{:.3f}; delta {:+.3f} [95% CI {:+.3f}, {:+.3f}]".format(
                metric, statistics.mean(blocks[True]), statistics.mean(blocks[False]),
                effect["mean"], effect["low"], effect["high"]))
            if metric in ["win", "dpt"]:
                hypotheses.append((effect["p"], "/".join(key) + "/" + metric))
        both_wins = [s[True][seed]["turns"] - s[False][seed]["turns"]
                     for s in strata for seed in seeds
                     if s[True][seed]["win"] and s[False][seed]["win"]]
        if both_wins:
            print("  Both-win pairs: {}; mean turn delta {:+.2f} (conditional)".format(
                len(both_wins), statistics.mean(both_wins)))
    previous = 0.0
    print("Holm-adjusted paired p-values across win and damage/turn group comparisons:")
    for index, (p, name) in enumerate(sorted(hypotheses)):
        adjusted = min(1.0, max(previous, p * (len(hypotheses) - index)))
        previous = adjusted
        print("  {}: {:.5f}".format(name, adjusted))
    print("CIs are exploratory, unadjusted paired Student-t intervals. Reused weapon seeds")
    print("count once per block. Shorter fights can mean earlier death; read wins and damage together.")


if __name__ == "__main__":
    main()
