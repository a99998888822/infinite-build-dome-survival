"""Validate equal-work damage bursts and real-render hit-pose controls."""
import json
import statistics
from summarize_reflection_optimization import REPORTS, read_run, summarize


def main():
    rows = read_run("hit_pose_actor_abba")
    assert len(rows) == 8
    keys = ("count", "sites", "hits", "damage", "trace_hash", "hp", "visual_tiers")
    for index, row in enumerate(rows):
        assert row["hit_pose_baseline"] == (index in (0, 3, 5, 6))
        assert len(row["samples"]) == 60
        assert all(row[key] == rows[0][key] for key in keys)
        for old, current in zip(rows[0]["timings"], row["timings"]):
            assert all(old[key] == current[key] for key in ("step", "active", "hits"))
    before = [row for row in rows if row["hit_pose_baseline"]]
    after = [row for row in rows if not row["hit_pose_baseline"]]
    result = {"equal_work": True, "runs_each": 4, "frames_each": 240,
              "before": summarize(before), "after": summarize(after),
              "signature": {key: rows[0][key] for key in keys}}
    for name, group in (("before", before), ("after", after)):
        result[name]["damage_mean_ms"] = statistics.mean(row["frames"]["damage_ms"]["mean"] for row in group)
        result[name]["peak_sample"] = max((s for row in group for s in row["samples"]), key=lambda s: s["frame_ms"])
    burst = json.loads((REPORTS / "hit_pose_damage_review.json").read_text(encoding="utf-8"))
    assert burst["failures"] == 0 and len(burst["rows"]) == 8
    reference = burst["rows"][0]
    for row in burst["rows"]:
        assert all(row[key] == reference[key] for key in ("hits", "damage", "trace", "hp", "poses", "next_random", "numbers"))
    result["burst"] = {name: {key: statistics.mean(row[key] for row in burst["rows"] if row["baseline"] == baseline)
                             for key in ("cpu_ms", "submit_ms", "flush_ms")}
                       for name, baseline in (("before", True), ("after", False))}
    result["reduction_percent"] = {key: 100 * (1 - result["after"][key] / value) if value else None
                                   for key, value in result["before"].items() if isinstance(value, (int, float))}
    result["burst_reduction_percent"] = 100 * (1 - result["burst"]["after"]["cpu_ms"] / result["burst"]["before"]["cpu_ms"])
    result["runs"] = [{"baseline": row["hit_pose_baseline"], "frame_ms": row["frames"]["frame_ms"]} for row in rows]
    (REPORTS / "hit_pose_optimization_comparison.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("equal_work=True", "burst_reduction_percent=", result["burst_reduction_percent"])
    for key, change in result["reduction_percent"].items():
        print(key, result["before"][key], "->", result["after"][key], "reduction_percent=", change)


if __name__ == "__main__":
    main()
