extends RefCounted
## Neutral iron base with smoke-bronze accents for selected or focused controls.
const WARM = preload("res://scripts/ui/smoke_bronze_palette.gd")

const BACKDROP := Color("18191d")
const PANEL_FILL := Color("24262b")
const NODE_FILL := Color("2d3034")
const SHADOW := Color("101215")
const BORDER := Color("555b5e")
const METAL := Color("747c7b")
const BRONZE := WARM.BRONZE
const TEXT := Color("c6c7c2")
const MUTED := Color("8f9394")
const ACTIVE := Color("cbc6b5")
const ACTIVE_MID := Color("92968d")
const LINE_ACTIVE := Color("737b79")
const LINE_IDLE := Color("42474c")

const WARM_ACTIVE := WARM.ACTIVE
const WARM_TEXT := WARM.TEXT
const WARM_MUTED := WARM.MUTED
const WARM_NODE = WARM.NODE_SELECTED
const WARM_FRAME = WARM.FRAME_SELECTED

const NODE = preload("res://assets/ui/hud/neutral_iron/node_idle.png")
const NODE_LOCKED = preload("res://assets/ui/hud/neutral_iron/node_locked.png")
const NODE_SELECTED = preload("res://assets/ui/hud/neutral_iron/node_selected.png")
const BUTTON = preload("res://assets/ui/hud/neutral_iron/button.png")
const BUTTON_SELECTED = preload("res://assets/ui/hud/neutral_iron/button_hover.png")
const FRAME = preload("res://assets/ui/hud/neutral_iron/panel.png")
const FRAME_SELECTED = preload("res://assets/ui/hud/neutral_iron/panel_selected.png")
const UPGRADE_ARROW = WARM.UPGRADE_ARROW
