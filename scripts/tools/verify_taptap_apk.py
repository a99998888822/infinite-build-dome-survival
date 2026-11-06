"""Verify the exported TapTap Android artifact, including compiled game gates.

This checks packaging, not real-account certification or backend policy.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zipfile

import zstandard


def script_identifiers(data):
    if data[:4] != b"GDSC":
        raise ValueError("Expected a Godot compiled script")
    expected_size = struct.unpack_from("<I", data, 8)[0]
    if expected_size > 8 * 1024 * 1024:
        raise ValueError("Unexpected compiled-script size")
    decoded = zstandard.ZstdDecompressor().decompress(data[12:], max_output_size=expected_size)
    if len(decoded) != expected_size:
        raise ValueError("Compiled-script size mismatch")
    count = struct.unpack_from("<I", decoded)[0]
    offset = 16
    identifiers = set()
    for _ in range(count):
        length = struct.unpack_from("<I", decoded, offset)[0] * 4
        offset += 4
        value = bytes(byte ^ 0xB6 for byte in decoded[offset:offset + length])
        offset += length
        identifiers.add(value.decode("utf-32-le").rstrip("\0"))
    return identifiers


def verify_apk(path):
    path = Path(path).resolve()
    checks = []
    with zipfile.ZipFile(path) as apk:
        names = apk.namelist()
        dex = b"".join(apk.read(name) for name in names
                       if name.startswith("classes") and name.endswith(".dex"))
        for token in [
            b"Lcom/taptap/sdk/compliance/TapTapCompliance;",
            b"Lcom/taptap/sdk/compliance/internal/TapComplianceInternal;",
            b"Lcom/octopus/goblin/taptap/TapTapGodotPlugin;",
            b"startCompliance", b"complianceResult", b"compliance-v2",
        ]:
            if token not in dex:
                raise ValueError("APK missing SDK/bridge component: " + token.decode("ascii"))
        checks.append("compliance_sdk_and_bridge_v2")
        scripts = {
            "autoloads/taptap_session": {
                "_compliance_passed", "_on_compliance_result", "can_enter_game", "_start_compliance",
            },
            "scripts/core/game_root": {"_on_taptap_state_changed", "_battle_runtime_pause_requested"},
            "scripts/core/main_flow_coordinator": {"_battle_runtime_pause_requested", "can_enter_game"},
        }
        for script, required in scripts.items():
            found = script_identifiers(apk.read("assets/" + script + ".gdc"))
            if missing := required - found:
                raise ValueError("Stale gameplay script " + script + ": " + repr(sorted(missing)))
        checks.append("compiled_login_and_runtime_gates")
        project = apk.read("assets/project.binary")
        if b"autoload/TapTapSession" not in project:
            raise ValueError("TapTapSession autoload not registered in APK")
        checks.append("session_autoload_registered")
        config = json.loads(apk.read("assets/data_config/platform/taptap.json"))
        if not all(config.get(key) for key in ["client_id", "client_token", "privacy_policy_url"]):
            raise ValueError("Missing required SDK configuration")
        checks.append("sdk_configuration_present")
        if any(name.startswith(("assets/scripts/tests/", "assets/scenes/tests/")) for name in names):
            raise ValueError("Test assets must not be exported")
        checks.append("test_assets_excluded")
    with path.open("rb") as stream:
        checksum = hashlib.file_digest(stream, "sha256").hexdigest()
    return {
        "apk": str(path), "bytes": path.stat().st_size,
        "sha256": checksum,
        "checks": checks,
        "real_account_verification": "pending_device_and_backend_validation",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("apk", type=Path)
    args = parser.parse_args()
    report = verify_apk(args.apk)
    report_path = args.apk.with_suffix(".verification.json")
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
