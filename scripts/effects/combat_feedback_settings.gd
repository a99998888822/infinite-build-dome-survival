extends RefCounted
## Approved combat feedback is on by default; comparisons may override it locally.
const FLAG := "combat_feedback_r02_enabled"


static func enabled() -> bool:
	return bool(GameGlobal.get_runtime_flag(FLAG, true))
