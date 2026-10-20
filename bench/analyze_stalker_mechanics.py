"""Summarize encounter experiments without treating repeated seeds as independent."""

import argparse
import json
import random
import statistics
from collections import defaultdict
from pathlib import Path


def summarize(fights):
    reached = [fight for fight in fights if fight["channel_started"]]
    passed = [fight for fight in reached if fight["channel_success"]]
    result = {
        "n": len(fights),
        "win": round(100 * sum(fight["win"] for fight in fights) / len(fights), 1),
        "reach": round(100 * len(reached) / len(fights), 1),
        "pass": round(100 * len(passed) / len(reached), 1) if reached else None,
        "turns": statistics.median(fight["turns"] for fight in fights),
        "hp": statistics.median(fight["hp"] for fight in fights),
        "window_damage": statistics.median(fight["channel_damage"] for fight in reached) if reached else None,
        "healed": round(statistics.mean(fight["boss_healing"] for fight in fights), 1),
    }
    if any("cone_casts" in fight for fight in fights):
        impacts = sum(fight.get("cone_impacts", 0) for fight in fights)
        result.update({
            "cones": round(statistics.mean(fight.get("cone_casts", 0) for fight in fights), 2),
            "impacts": round(impacts / len(fights), 2),
            "hit_percent": round(100 * sum(fight.get("cone_hits", 0) for fight in fights) / impacts, 1) if impacts else 0,
            "dodge_steps": round(statistics.mean(fight.get("dodge_steps", 0) for fight in fights), 2),
            "pets_lost": round(statistics.mean(fight.get("cone_pet_kills", 0) for fight in fights), 2),
        })
        execute_phase = [fight for fight in fights if fight.get("enrage_turn", -1) >= 0]
        if execute_phase:
            result.update({
                "execute_phase_turns": round(statistics.mean(
                    fight["turns"] + fight["preparation_turns"] - fight["enrage_turn"]
                    for fight in execute_phase), 2),
                "execute_phase_incoming": round(statistics.mean(
                    fight["enrage_incoming"] for fight in execute_phase), 1),
                "execute_phase_zero_damage_percent": round(100 * sum(
                    fight["enrage_incoming"] == 0 for fight in execute_phase) / len(execute_phase), 1),
            })
    return result


def paired_delta(outcomes, reference):
    blocks = defaultdict(list)
    for stratum, win in outcomes.items():
        if stratum in reference:
            blocks[stratum[-1]].append(win - reference[stratum])
    deltas = [statistics.mean(block) for block in blocks.values()]
    if not deltas:
        return None
    rng = random.Random(98765)
    bootstrap = sorted(
        statistics.mean(rng.choices(deltas, k=len(deltas)))
        for _ in range(2000)
    )
    return {"seed_blocks": len(deltas),
            "win_delta_pp": round(100 * statistics.mean(deltas), 1),
            "bootstrap_95_pp": [round(100 * bootstrap[49], 1),
                                round(100 * bootstrap[1949], 1)]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("results", nargs="+", type=Path)
    parser.add_argument("--cells", action="store_true")
    parser.add_argument("--by-build", action="store_true")
    parser.add_argument("--three-only", action="store_true")
    parser.add_argument("--paired", action="store_true")
    args = parser.parse_args()
    groups = defaultdict(list)
    seen = set()
    matched = defaultdict(dict)
    baseline_policy = "ordinary"
    for path in args.results:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
        baseline_policy = data.get("setup", {}).get("baseline_policy", baseline_policy)
        for row in data["rows"]:
            if args.three_only and row["build"] == "All":
                continue
            cell = (row["build"], row["weapon"], row["config"]["id"], row["policy"])
            if cell in seen:
                raise ValueError(f"Overlapping cell: {cell}")
            seen.add(cell)
            key = (row["config"]["id"], row["policy"])
            if args.by_build:
                key = (row["build"], *key)
            groups[cell if args.cells else key].extend(row["fights"])
            for fight in row["fights"]:
                matched[(row["config"]["id"], row["policy"])][
                    (row["build"], row["weapon"], fight["seed"])
                ] = int(fight["win"])
    print("Uncertainty: reused seeds span cells; pooled percentages describe these fixed strata, not independent trials.")
    for key, fights in groups.items():
        print(json.dumps({"cell": key, **summarize(fights)}))
    if args.paired:
        baseline = matched[("live", baseline_policy)]
        for key, outcomes in matched.items():
            if key == ("live", baseline_policy):
                continue
            references = {"live": baseline}
            if key[1] != baseline_policy:
                references[baseline_policy] = matched.get((key[0], baseline_policy), {})
            if ("live", key[1]) in matched and key[1] != baseline_policy:
                references["same_policy_live"] = matched[("live", key[1])]
            if key[0] == "enrage-cone":
                references["enrage"] = matched.get(("enrage", key[1]), matched.get(("enrage", baseline_policy), {}))
            for label, reference in references.items():
                delta = paired_delta(outcomes, reference)
                if delta is not None:
                    print(json.dumps({"comparison": key, "versus": label, **delta}))


if __name__ == "__main__":
    main()
