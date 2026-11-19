class_name BlubberbeardSkillData
extends BossSkillData
## Cấu hình thông số từng kỹ năng của Captain Blubberbeard.

enum Kind {
	POWDER_BARREL,
	SKY_DIVE,
	SPIKY_INFLATION,
	ANCHOR_SLAM,
	ANCHOR_WHIRLWIND,
	VENOM_SPIT,
}

@export var kind: Kind = Kind.POWDER_BARREL
@export_range(0.1, 20.0, 0.1, "suffix:m") var radius: float = 2.5
@export_range(0.1, 50.0, 0.1, "suffix:m/s") var speed: float = 10.0
@export_range(0.1, 10.0, 0.1, "suffix:s") var duration: float = 1.0

@export_group("Barrel Barrage")
@export var barrel_escalating_burst: bool = true
@export_range(1, 8, 1) var barrel_final_burst_min: int = 3
@export_range(1, 8, 1) var barrel_final_burst_max: int = 3
@export var randomize_barrel_throws: bool = true
@export_range(1, 8, 1) var barrel_throw_count: int = 3
@export_range(1, 8, 1) var barrel_throw_min: int = 1
@export_range(1, 8, 1) var barrel_throw_max: int = 3
@export_range(0.25, 2.5, 0.05, "suffix:s") var barrel_throw_duration: float = 0.62
@export_range(0.05, 1.5, 0.05, "suffix:s") var barrel_throw_gap_min: float = 0.24
@export_range(0.05, 2.0, 0.05, "suffix:s") var barrel_throw_gap_max: float = 0.42
@export_range(0.5, 8.0, 0.1, "suffix:m") var barrel_spread_min_radius: float = 2.0
@export_range(1.0, 12.0, 0.1, "suffix:m") var barrel_spread_max_radius: float = 4.6

@export_group("Parabolic Leap (Sky Dive)")
@export_range(2.0, 12.0, 0.2, "suffix:m") var skydive_peak_height: float = 5.4
@export_range(0.35, 2.5, 0.05, "suffix:s") var skydive_leap_duration: float = 0.82
@export_range(3.0, 25.0, 0.5, "suffix:m") var skydive_max_range: float = 14.0

@export_group("Spiky Inflation")
@export_range(0.3, 3.0, 0.05, "suffix:s") var spiky_hold_duration: float = 1.25

@export_group("Anchor Whirlwind")
@export_range(1, 4, 1) var whirlwind_rotations_min: int = 2
@export_range(1, 4, 1) var whirlwind_rotations_max: int = 2
@export_range(2.0, 10.0, 0.2, "suffix:m") var whirlwind_reach_radius: float = 6.0
@export_range(1.0, 15.0, 0.2, "suffix:rad/s") var whirlwind_angular_speed: float = 7.2

@export_group("Venom Spit")
@export_range(1, 8, 1) var venom_shot_count: int = 3
@export_range(0.0, 120.0, 5.0, "suffix:deg") var venom_spread_angle_deg: float = 40.0
@export_range(0.8, 6.0, 0.1, "suffix:m") var venom_pool_radius: float = 2.4
@export_range(1.0, 10.0, 0.2, "suffix:s") var venom_pool_duration: float = 4.5
@export_range(0.1, 2.0, 0.05) var venom_tick_damage: float = 0.5
@export_range(0.2, 2.0, 0.05, "suffix:s") var venom_tick_interval: float = 0.75
