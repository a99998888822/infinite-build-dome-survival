"""Capture real goblin loan/challenge and vault-defense story pickups."""
import sys
import record_greed_promo as runner

runner.SCENE = "res://scenes/debug/goblin_contracts_promo.tscn"
runner.NAMES = {
    "debt_bank": "debt_bank.mp4",
    "debt_fight": "debt_fight.mp4",
    "vault_offer": "vault_offer.mp4",
    "vault_rescue": "vault_rescue.mp4",
}

if __name__ == "__main__":
    if "--output" not in sys.argv:
        sys.argv += ["--output", str(runner.PROJECT / "artifacts/previews/goblin_contracts_20261024")]
    raise SystemExit(runner.main())
