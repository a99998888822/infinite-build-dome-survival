"""Validate same-process ABBA controls and summarize long-frame measurements."""
import json
import sys
from summarize_reflection_optimization import REPORTS, read_run, summarize


def describe(rows):
    result = summarize(rows)
    samples = [sample for row in rows for sample in row["samples"]]
    result["sweep_mean_ms"] = result["sweep_total_ms_per_run"] / 60
    result["damage_mean_ms"] = sum(s["damage_ms"] for s in samples) / len(samples)
    for key in ("before_render_ms", "render_stage_ms", "exit_signal_span_ms"):
        if all(key in sample for sample in samples):
            result[key] = {"mean": sum(s[key] for s in samples) / len(samples),
                           "max": max(s[key] for s in samples)}
    peak = max(samples, key=lambda sample: sample["frame_ms"])
    result["peak_sample"] = peak
    return result


def main():
    stem = sys.argv[1]
    inputs = sys.argv[2:] or [stem]
    rows = [row for source in inputs for row in read_run(source)]
    keys = ("count", "sites", "hits", "damage", "trace_hash", "hp", "visual_tiers")
    reference = rows[0]
    assert len(rows) % 4 == 0
    for i, row in enumerate(rows):
        baseline = i % 4 in (0, 3)
        if row.get("shared_control_order", "ABBA") == "BAAB":
            baseline = not baseline
        assert row["shared_baseline"] == baseline
        assert len(row["samples"]) == len(row["timings"]) == 60
        assert all(row[key] == reference[key] for key in keys)
        for old, new in zip(reference["timings"], row["timings"]):
            assert all(old[key] == new[key] for key in ("step", "active", "hits"))
    before = [row for row in rows if row["shared_baseline"]]
    after = [row for row in rows if not row["shared_baseline"]]
    result = {"equal_work": True, "inputs": inputs, "runs_each": len(before), "frames_each": 60 * len(before),
              "signature": {key: reference[key] for key in keys},
              "before": describe(before), "after": describe(after)}
    result["reduction_percent"] = {
        key: 100 * (1 - result["after"][key] / value) if value else None
        for key, value in result["before"].items() if isinstance(value, (int, float))}
    result["runs"] = [{"repeat": r["repeat"], "baseline": r["shared_baseline"],
                       "metrics": describe([r])} for r in rows]
    (REPORTS / f"{stem}_comparison.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("equal_work=True", "runs_each=", len(before))
    for key, change in result["reduction_percent"].items():
        print(f"{key}: {result['before'][key]:.3f} -> {result['after'][key]:.3f}; reduction={change}")
    for row in rows:
        print("run", row["repeat"], "baseline", row["shared_baseline"], row["frames"]["frame_ms"])
    for name in ("before", "after"):
        print(name, "peak", json.dumps(result[name]["peak_sample"]))


if __name__ == "__main__":
    main()
