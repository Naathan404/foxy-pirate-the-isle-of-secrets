class_name BarrelInkHit
extends Resource
## What a Barrel's ink blob does to Foxy on a hit that costs HP: pushes them along the blob's
## flight, slows them for a moment and splatters ink over the screen.

const INK_OVERLAY_SCRIPT: Script = preload("res://gameplay/player/effects/ink_overlay.gd")
const INK_OVERLAY_NAME := "BarrelInkOverlay"

@export_group("Push")
## Scales the player's normal hit knockback and hop; 0 means no push.
@export_range(0.0, 2.0, 0.05) var knockback_multiplier: float = 0.6

@export_group("Slow")
@export_range(0.0, 5.0, 0.05, "suffix:s") var slow_seconds: float = 1.2
## Move speed while slowed; 0.75 is 25% slower. Does not stack with other slows.
@export_range(0.1, 1.0, 0.05) var slow_speed_multiplier: float = 0.75

@export_group("Screen Ink")
@export var ink_color: Color = Color(0.36, 0.17, 0.24, 1.0)
@export_range(0.0, 1.0, 0.01) var ink_opacity: float = 0.75
## How far the splats spread; 0.125 is their base size, 1 covers the whole screen.
@export_range(0.0, 1.0, 0.005) var ink_coverage: float = 0.12
@export_range(0.01, 3.0, 0.01, "suffix:s") var ink_spread_seconds: float = 0.12
@export_range(0.0, 10.0, 0.05, "suffix:s") var ink_hold_seconds: float = 0.35
@export_range(0.01, 10.0, 0.05, "suffix:s") var ink_fade_seconds: float = 0.9


func apply_to(player: Player) -> void:
	player.apply_snare(slow_seconds, slow_speed_multiplier)
	# The player owns the overlay, so it keeps fading after the blob and barrel are gone.
	var overlay := player.get_node_or_null(INK_OVERLAY_NAME)
	if overlay == null:
		overlay = INK_OVERLAY_SCRIPT.new()
		overlay.name = INK_OVERLAY_NAME
		player.add_child(overlay)
	overlay.splash(
		false,
		ink_color,
		ink_spread_seconds,
		ink_hold_seconds,
		ink_fade_seconds,
		ink_opacity,
		ink_coverage
	)
