extends RefCounted
## Independent hammer ground and ritual source cues; not the general hit response.
const FLAG := "combat_feedback_r02_enabled"


static func enabled() -> bool:
	return bool(GameGlobal.get_runtime_flag(FLAG, true))
