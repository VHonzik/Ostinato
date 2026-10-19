"""Summarize live priority comparisons; console output only."""

import argparse
import json
import statistics
from pathlib import Path


def mean(values):
    return statistics.mean(values)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("results", type=Path, nargs="+")
    args = parser.parse_args()
    rows = []
    replays = 0
    matrix = None
    seen = set()
    for path in args.results:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
        setup = data["setup"]
        identity = json.dumps({key: setup[key] for key in
                               ("samples", "builds", "variants", "cases", "rules")},
                              sort_keys=True)
        if matrix is not None and matrix != identity:
            parser.error("Combine only weapon shards from the same matrix.")
        matrix = identity
        for row in data["rows"]:
            key = (row["build"], row["variant"], row["weapon"], row["case"], row["prepared"])
            if key in seen:
                parser.error("Duplicate matrix cell; inputs overlap.")
            seen.add(key)
            rows.append(row)
        replays += data["replayed"]
    print("{} measured fights; {} plain-world replays".format(
        sum(row["runs"] for row in rows), replays))
    print("Stalker under intent policy: wins %, mean turns, full Lava/fight")
    builds = list(dict.fromkeys(row["build"] for row in rows))
    for prepared in (False, True):
        for build in builds:
            cells = [r for r in rows if r["case"] == "Stalker"
                     and r["prepared"] == prepared and r["variant"] == "intent"
                     and r["build"] == build]
            fights = [f for row in cells for f in row["fights"]]
            print("{:<25} {:<8} {:5.1f} {:6.2f} {:5.2f}".format(
                build, "prepared" if prepared else "cold",
                100 * mean([int(f["win"]) for f in fights]),
                mean([f["turns"] for f in fights]),
                mean([f.get("full_lava", 0) for f in fights])))
    print("Prepared complete kit: mean turns, Consecration casts/fight")
    cases = list(dict.fromkeys(r["case"] for r in rows))
    variants = list(dict.fromkeys(r["variant"] for r in rows))
    for case in cases:
        for variant in variants:
            cells = [r for r in rows if r["case"] == case and r["prepared"]
                     and r["variant"] == variant and r["build"] == "All"]
            fights = [f for r in cells for f in r["fights"]]
            print("{:<10} {:<13} {:6.2f} {:5.2f}".format(case, variant,
                mean([f["turns"] for f in fights]),
                mean([r["casts"].get("Consecration", 0) / r["runs"] for r in cells])))
    print("Prepared complete-kit Stalker paired turn delta vs intent (negative is faster)")
    print("Seed blocks average weapons first; observed range is descriptive, not a CI.")
    baseline = {r["weapon"]: r for r in rows if r["case"] == "Stalker"
                and r["prepared"] and r["variant"] == "intent" and r["build"] == "All"}
    for variant in variants:
        if variant == "intent":
            continue
        cells = [r for r in rows if r["case"] == "Stalker" and r["prepared"]
                 and r["variant"] == variant and r["build"] == "All"]
        by_seed = {}
        for row in cells:
            base = {f["seed"]: f for f in baseline[row["weapon"]]["fights"]}
            for fight in row["fights"]:
                by_seed.setdefault(fight["seed"], []).append(
                    fight["turns"] - base[fight["seed"]]["turns"])
        blocks = [mean(values) for values in by_seed.values()]
        print("{:<13} {:+.2f} (seed-block range {:+.2f} to {:+.2f})".format(
            variant, mean(blocks), min(blocks), max(blocks)))


if __name__ == "__main__":
    main()
