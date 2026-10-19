"""Print pull throughput and survival summaries from nonoverlapping weapon shards."""

import argparse
import json
import statistics as stats
from pathlib import Path


def summarize(row):
    fights = row["fights"]
    winners = [fight for fight in fights if fight["win"]]
    turns = sum(fight["turns"] for fight in fights)
    damage = sum(fight["damage_total"] for fight in fights)
    taken = sum(fight["raw_damage_taken"] for fight in fights)
    healing = sum(fight["healing_total"] for fight in fights)
    victory = sum(fight["healing"].get("Victory Rush", 0) for fight in fights)
    return {
        "weapon": row["weapon"], "quality": row["quality"], "profile": row["profile"],
        "entry": row["entry"], "policy": row["policy"], "count": row["count"],
        "candidate": row.get("candidate", "live"), "defense": row.get("defense", "emergency"),
        "wins": len(winners), "samples": len(fights),
        "mean_turns": stats.mean(fight["turns"] for fight in fights),
        "win_mean_turns": stats.mean(fight["turns"] for fight in winners) if winners else None,
        "turn_range": [min(fight["turns"] for fight in fights), max(fight["turns"] for fight in fights)],
        "mobs_per_turn": sum(fight["kills"] for fight in fights) / turns,
        "damage_per_turn": damage / turns, "taken_per_turn": taken / turns,
        "net_loss_per_turn": (taken - healing) / turns,
        "mean_taken": taken / len(fights), "mean_healing": healing / len(fights),
        "mean_victory_healing": victory / len(fights),
        "mean_final_hp": stats.mean(fight["hp"] for fight in fights),
        "median_minimum_hp": stats.median(fight["minimum_hp"] for fight in fights),
        "worst_minimum_hp": min(fight["minimum_hp"] for fight in fights),
        "mean_peak_taken": stats.mean(fight["peak_taken"] for fight in fights),
        "worst_peak_taken": max(fight["peak_taken"] for fight in fights),
        "stats": fights[0]["stats"],
        "mean_defense_casts": {name: stats.mean(fight["casts"].get(name, 0) for fight in fights)
                               for name in ("Divine Shield", "Evasion")},
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("results", nargs="+", type=Path)
    parser.add_argument("--json", action="store_true", help="Emit compact summaries as JSON")
    args = parser.parse_args()
    rows = []
    seen = set()
    for path in args.results:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
        for row in data["rows"]:
            key = tuple(row[field] for field in ("weapon", "quality", "profile", "entry", "policy", "count"))
            key += (row.get("candidate", "live"), row.get("defense", "emergency"))
            if key in seen:
                raise ValueError(f"Overlapping cell: {key}")
            seen.add(key)
            rows.append(summarize(row))
    if args.json:
        print(json.dumps(rows, indent=2))
        return
    tuning = any(row["candidate"] != "live" or row["defense"] != "emergency" for row in rows)
    print(("candidate         defense   " if tuning else "") +
          "weapon gear     profile entry           policy  mobs wins  turns   kills/t  in/t  net/t  HPend  HPmin peak")
    for row in rows:
        prefix = f'{row["candidate"]:17} {row["defense"]:9} ' if tuning else ""
        print(prefix + f'{row["weapon"]:6} {row["quality"]:8} {row["profile"]:7} {row["entry"]:15} '
              f'{row["policy"]:6} {row["count"]:4} {row["wins"]:2}/{row["samples"]:<2} '
              f'{row["mean_turns"]:6.1f} {row["mobs_per_turn"]:8.3f} '
              f'{row["taken_per_turn"]:5.1f} {row["net_loss_per_turn"]:6.1f} '
              f'{row["mean_final_hp"]:6.1f} {row["worst_minimum_hp"]:5} '
              f'{row["worst_peak_taken"]:4}')
    print("in/t = post-mitigation incoming damage, including fatal overkill, per elapsed fight turn.")
    print("net/t subtracts effective healing; HPmin and peak are worst observed, not expectations.")
    print("Kills/t includes partial kills in losses; read it together with wins and turns.")


if __name__ == "__main__":
    main()
