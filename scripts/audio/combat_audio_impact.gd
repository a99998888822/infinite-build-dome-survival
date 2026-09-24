extends RefCounted

# A single contact (including immediate/deferred children), never a whole frame
# or a shared DamageEvent. Keep suppression for late fire seeds from that contact.
const REPLACEMENTS: Dictionary = {
	"steam": ["water", "fire"],
	"freeze": ["water", "ice"],
	"holy": ["light_sword", "fire"],
	"dark_flame": ["black_hole", "fire"],
	"cancel": ["light_sword", "black_hole"],
	"conduct": ["water", "lightning", "electric_spark"],
	"thunder_fire": ["fire", "lightning", "electric_spark", "explosion"],
	"wet_spread": ["wind", "water"],
	"ice_expand": ["wind", "ice"],
	"reflection": ["light_sword", "ice", "water", "reaction_freeze"],
}

var requests: Dictionary = {}
var suppressed_cues: Dictionary = {}
var reactions: Dictionary = {}
var has_ground_strike: bool = false
var has_reaction: bool = false
var queued: bool = false
var request_frame: int = 0


func mark_reaction(reaction_id: String) -> void:
	if not REPLACEMENTS.has(reaction_id):
		return
	has_reaction = true
	reactions[reaction_id] = true
	for cue: String in REPLACEMENTS[reaction_id]:
		suppressed_cues[cue] = true


func request(cue_id: String, interval_ms: int, is_weapon: bool) -> void:
	if cue_id == "electric_spark":
		has_ground_strike = true
	var previous: Dictionary = requests.get(cue_id, {})
	requests[cue_id] = {
		"interval_ms": maxi(interval_ms, int(previous.get("interval_ms", 0))),
		"is_weapon": is_weapon or bool(previous.get("is_weapon", false)),
	}


func resolve_cue(cue_id: String) -> String:
	# Keep the landing's thunder body inside its combined reaction sound.
	# The scope survives deferred explosions, while later chain hops use a new one.
	if has_ground_strike:
		if cue_id == "reaction_thunder_fire":
			return "reaction_thunder_fire_strike"
		if cue_id == "reaction_conduct":
			# One landing gets one thunder onset even if different targets react.
			return "" if reactions.has("thunder_fire") else "reaction_conduct_strike"
	return cue_id
