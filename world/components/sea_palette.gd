class_name SeaPalette
extends Resource
## One mood for a Coral Valley room: lagoon water, sky, sun and screen grade. SeaMood blends
## between palettes at runtime (for example a boss arena turning violet in phase 2).

@export_group("Lagoon")
@export var deep_color := Color(0.02, 0.07, 0.11)
@export var lagoon_color := Color(0.04, 0.23, 0.28)
@export var shallow_color := Color(0.14, 0.47, 0.47)
@export var reef_color := Color(0.28, 0.22, 0.32)
@export var caustic_color := Color(0.62, 0.95, 0.88)
@export var foam_color := Color(0.9, 0.95, 0.9)
@export_range(0.0, 1.0, 0.01) var caustic_strength: float = 0.2

@export_group("Sky")
@export var background_color := Color(0.02, 0.07, 0.11)
@export var ambient_color := Color(0.5, 0.62, 0.66)
@export_range(0.0, 2.0, 0.01) var ambient_energy: float = 0.6
@export_range(0.0, 2.0, 0.01) var glow_intensity: float = 0.6

@export_group("Sun")
@export var sun_color := Color(1.0, 0.92, 0.84)
@export_range(0.0, 3.0, 0.01) var sun_energy: float = 1.15

@export_group("Grade")
@export var shadow_tint := Color(0.9, 0.98, 1.0)
@export var highlight_tint := Color(1.07, 0.97, 0.9)
@export_range(0.0, 2.0, 0.01) var saturation: float = 0.98
@export var vignette_color := Color(0.02, 0.09, 0.12)
@export_range(0.0, 1.0, 0.01) var vignette_strength: float = 0.3
