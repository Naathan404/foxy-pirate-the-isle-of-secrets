class_name MeleeComboStep
extends Resource
## One authored swing. Damage is a multiplier of AttackData, before forge/charm modifiers.

@export_range(0.0, 1.0, 0.005) var windup_seconds: float = 0.065
@export_range(0.02, 1.0, 0.005) var active_seconds: float = 0.1
@export_range(0.0, 1.0, 0.005) var recovery_seconds: float = 0.1
@export_range(0.1, 5.0, 0.05) var damage_multiplier: float = 1.0
@export_range(0.0, 3.0, 0.05) var knockback_multiplier: float = 0.5
@export_range(0.0, 1.0, 0.01) var movement_multiplier: float = 0.18
@export_range(0.0, 0.6, 0.01) var step_distance: float = 0.28
@export_range(0.02, 0.4, 0.01) var step_duration: float = 0.12
## Fraction of recovery that must finish before dash can cancel.
@export_range(0.0, 1.0, 0.05) var dash_cancel_fraction: float = 0.45
@export_range(-160.0, 160.0, 1.0) var swing_start_degrees: float = -65.0
@export_range(-160.0, 160.0, 1.0) var swing_end_degrees: float = 65.0
@export_range(0.5, 2.0, 0.05) var reach_multiplier: float = 1.0
@export_range(0.05, 1.2, 0.01) var slash_width: float = 0.62
@export var slash_color: Color = Color(1.0, 0.8, 0.4)
@export_range(0.0, 0.12, 0.005) var hitstop_seconds: float = 0.035
@export_range(0.0, 8.0, 0.25) var shake_pixels: float = 1.5
@export_range(0.5, 2.0, 0.05) var audio_pitch: float = 1.2
@export var heavy_impact: bool = false
## Optional future animation set; empty reuses AttackData.animation_prefix.
@export var animation_prefix: String = ""


func is_valid() -> bool:
	return (
		windup_seconds >= 0.0
		and active_seconds > 0.0
		and recovery_seconds >= 0.0
		and damage_multiplier > 0.0
		and reach_multiplier > 0.0
		and step_duration > 0.0
	)
