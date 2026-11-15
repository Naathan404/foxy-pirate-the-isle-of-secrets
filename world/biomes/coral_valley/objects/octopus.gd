extends DestructibleProp
## Ink lands on the attacking player's screen, including the killing hit.

const INK_OVERLAY_SCRIPT: Script = preload("res://gameplay/player/effects/ink_overlay.gd")
const INK_OVERLAY_NAME := "OctopusInkOverlay"

@export_group("Ink Splash")
@export var ink_color := Color(0.015, 0.012, 0.02, 1.0)
@export_range(0.0, 1.0, 0.01) var hit_ink_opacity := 0.88
@export_range(0.01, 3.0, 0.01, "suffix:s") var hit_spread_time := 0.16
@export_range(0.0, 10.0, 0.05, "suffix:s") var hit_hold_time := 0.65
@export_range(0.01, 10.0, 0.05, "suffix:s") var hit_fade_time := 1.4
@export_range(0.0, 1.0, 0.01) var defeat_ink_opacity := 1.0
@export_range(0.01, 3.0, 0.01, "suffix:s") var defeat_spread_time := 0.5
@export_range(0.0, 10.0, 0.05, "suffix:s") var defeat_hold_time := 1.4
@export_range(0.01, 10.0, 0.05, "suffix:s") var defeat_fade_time := 3.0


func receive_damage(damage: DamageContext) -> float:
	var applied := super.receive_damage(damage)
	if applied <= 0.0 or damage == null or not is_instance_valid(damage.source):
		return applied
	var player := damage.source as Player
	if player == null:
		return applied
	var overlay := player.get_node_or_null(INK_OVERLAY_NAME)
	if overlay == null:
		overlay = INK_OVERLAY_SCRIPT.new()
		overlay.name = INK_OVERLAY_NAME
		player.add_child(overlay)
	if _destroyed:
		overlay.splash(true, ink_color, defeat_spread_time, defeat_hold_time, defeat_fade_time, defeat_ink_opacity)
	else:
		overlay.splash(false, ink_color, hit_spread_time, hit_hold_time, hit_fade_time, hit_ink_opacity)
	return applied
