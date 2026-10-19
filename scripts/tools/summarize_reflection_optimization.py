"""Validate equal-work GPU A/B reports and export reproducible cost tables."""
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[2]
REPORTS = ROOT / "artifacts/reports"


def read_run(stem):
    proof = json.loads((REPORTS / f"{stem}.json").read_text(encoding="utf-8"))
    assert proof["exit_code"] == 0 and proof["foreground_samples"] == 0, proof
    assert proof["verified_desktop"] == proof["private_desktop"], proof
    log = (REPORTS / f"{stem}.log").read_text(encoding="utf-8")
    for marker in ("SCRIPT ERROR", "Parse Error", "Compile Error", "ERROR:", "FAIL "):
        assert marker not in log, (stem, marker)
    rows = json.loads((REPORTS / f"{stem}_metrics.json").read_text(encoding="utf-8"))
    assert rows and all(not r["headless"] for r in rows)
    return rows


def summarize(rows):
    frames = sorted(s["frame_ms"] for r in rows for s in r["samples"])
    timings = [s for r in rows for s in r["timings"]]
    return {
        "frame_mean_ms": sum(frames) / len(frames),
        "frame_p95_ms": frames[int(len(frames) * 0.95)],
        "frame_p99_ms": frames[int(len(frames) * 0.99)],
        "frame_max_ms": max(frames),
        "frames_over_33ms": sum(t > 33.33 for t in frames),
        "frames_over_50ms": sum(t > 50 for t in frames),
        "frames_over_100ms": sum(t > 100 for t in frames),
        "spawn_total_ms_per_run": sum(t["spawn_ms"] for t in timings) / len(rows),
        "spawn_peak_ms": max(t["spawn_ms"] for t in timings),
        "sweep_total_ms_per_run": sum(t["sweep_ms"] for t in timings) / len(rows),
        "sweep_peak_ms": max(t["sweep_ms"] for t in timings),
    }


def main():
    prefix = sys.argv[1] if len(sys.argv) > 1 else "reflection_opt_fixed"
    before = read_run(prefix + "_before")
    after = read_run(prefix + "_after")
    assert len(before) == len(after)
    signatures = ("count", "sites", "hits", "damage", "trace_hash", "hp", "visual_tiers")
    for old, new in zip(before, after):
        assert old["legacy"] and not new["legacy"]
        for key in signatures:
            assert old[key] == new[key] == before[0][key], (key, old[key], new[key])
        assert len(old["samples"]) == len(new["samples"]) == 60
        for a, b in zip(old["timings"], new["timings"]):
            for key in ("step", "active", "hits"):
                assert a[key] == b[key], (key, a, b)
    result = {"equal_work": True, "runs_each": len(before), "frames_each": 60 * len(before),
              "signature": {k: before[0][k] for k in signatures},
              "before": summarize(before), "after": summarize(after)}
    result["reduction_percent"] = {k: 100 * (1 - result["after"][k] / v) if v else None
                                   for k, v in result["before"].items()}
    path = REPORTS / f"{prefix}_comparison.json"
    path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("equal_work=True; each run:", before[0]["count"], "beams;", before[0]["hits"], "hits;")
    for key, value in result["before"].items():
        delta = result["reduction_percent"][key]
        label = "n/a" if delta is None else f"{delta:.2f}%"
        print(f"{key}: {value:.3f} -> {result['after'][key]:.3f} ({label} reduction)")


if __name__ == "__main__":
    main()
