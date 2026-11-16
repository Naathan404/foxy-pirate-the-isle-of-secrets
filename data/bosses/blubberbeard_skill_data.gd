class_name BlubberbeardSkillData
extends BossSkillData

enum Kind { POWDER_BARREL, BELLY_CHARGE, SPIKY_INFLATION }

@export var kind: Kind = Kind.POWDER_BARREL
@export_range(0.1, 20.0, 0.1) var radius: float = 2.5
@export_range(0.1, 50.0, 0.1) var speed: float = 10.0
@export_range(0.1, 10.0, 0.1) var duration: float = 1.0

@export_group("Barrel Barrage")
@export var randomize_barrel_throws: bool = true
@export_range(1, 8, 1) var barrel_throw_count: int = 3
@export_range(1, 8, 1) var barrel_throw_min: int = 1
@export_range(1, 8, 1) var barrel_throw_max: int = 3
@export_range(0.25, 2.5, 0.05, "suffix:s") var barrel_throw_duration: float = 0.72
@export_range(0.05, 1.5, 0.05, "suffix:s") var barrel_throw_gap_min: float = 0.35
@export_range(0.05, 2.0, 0.05, "suffix:s") var barrel_throw_gap_max: float = 0.65
@export_range(0.5, 8.0, 0.1, "suffix:m") var barrel_spread_min_radius: float = 2.2
@export_range(1.0, 12.0, 0.1, "suffix:m") var barrel_spread_max_radius: float = 4.8
