"""Console summaries for aoe-interactions result files (Python standard library)."""

import argparse
import json
import statistics


def mean(values):
    return statistics.mean(values) if values else 0.0


def intervals(fights, key):
    return [b - a for fight in fights for a, b in zip(fight[key], fight[key][1:])]


def summarize(row):
    fights = row["fights"]
    turns = sum(f["turns"] for f in fights)
    vanish = intervals(fights, "vanish_turns")
    evasion = intervals(fights, "evasion_turns")
    attempts = sum(f.get("evasion_attempts", 0) for f in fights)
    hits = sum(f["evasion_hits"] for f in fights)
    return {
        "win": 100 * mean([int(f["win"]) for f in fights]),
        "HP": mean([f["hp"] for f in fights]),
        "turns": mean([f["turns"] for f in fights]),
        "taken": mean([f["raw_damage_taken"] for f in fights]),
        "healed": mean([f["healing_total"] for f in fights]),
        "Vcasts": mean([len(f["vanish_turns"]) for f in fights]),
        "Vgap": mean(vanish),
        "Vmin": min(vanish) if vanish else 0,
        "hidden%": 100 * sum(f["hidden_boundaries"] for f in fights) / turns,
        "Ecasts": mean([len(f["evasion_turns"]) for f in fights]),
        "Egap": mean(evasion),
        "E%": 100 * sum(f["evasion_boundaries"] for f in fights) / turns,
        "Ehit%": 100 * hits / attempts if attempts else 0,
        "blocked": mean([f["block_prevented"] for f in fights]),
        "hiddenDmg": mean([f["hidden_damage"] for f in fights]),
        "Vreduced": mean([f["vanish_reduction"] for f in fights]),
        "Ereduced": mean([f["evasion_reduction"] for f in fights]),
        "finishers": mean([len(f["finisher_points"]) for f in fights]),
        "WWcrit": mean([f["whirlwind_crits"] for f in fights]),
        "zeroDmg%": 100 * mean([int(f["raw_damage_taken"] == 0) for f in fights]),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="+")
    parser.add_argument("--count", type=int, default=16)
    parser.add_argument("--scale", type=int, default=1)
    parser.add_argument("--build", default="Warrior+Paladin+Rogue")
    parser.add_argument("--suite", choices=["offense", "defense"])
    parser.add_argument("--quality")
    parser.add_argument("--columns", default="win,HP,turns,taken,healed,Vcasts,Vgap,hidden%,E%,Ehit%")
    args = parser.parse_args()
    rows = []
    for path in args.paths:
        with open(path, encoding="utf-8-sig") as source:
            data = json.load(source)
        print("Run: {} cells, {} samples, {} replays".format(
            len(data["rows"]), data["setup"]["samples"], data["replayed"]))
        rows.extend(data["rows"])
    columns = args.columns.split(",")
    print("weapon quality suite policy " + " ".join(columns))
    for row in rows:
        if row["count"] != args.count or row["health_scale"] != args.scale:
            continue
        if row["build"] != args.build or args.suite and row["suite"] != args.suite:
            continue
        if args.quality and row["quality"] != args.quality:
            continue
        summary = summarize(row)
        print("{} {} {} {} {}".format(row["weapon"], row["quality"], row["suite"],
              row["policy"], " ".join("{:.1f}".format(summary[c]) for c in columns)))


if __name__ == "__main__":
    main()
