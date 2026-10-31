class_name PlayerData
extends Resource

# Lưu thông số gốc
const ANIM = {
	IDLE_DOWN = &"idle_down",
	IDLE_UP = &"idle_up",
	IDLE_SIDE = &"idle_side",
	RUN_DOWN = &"run_down",
	RUN_UP = &"run_up",
	RUN_SIDE = &"run_side",
	FALL_DOWN = &"fall_down",
	FALL_UP = &"fall_up",
	FALL_SIDE = &"fall_side",
	HIT_DOWN = &"hit_down",
	HIT_UP = &"hit_up",
	HIT_SIDE = &"hit_side",
	ATTACK_DAGGER_DOWN = &"attack_dagger_down",
	ATTACK_DAGGER_UP = &"attack_dagger_up",
	ATTACK_DAGGER_SIDE = &"attack_dagger_side",
}

@export_group("Health - HP")
@export_range(0.01, 20.0, 0.01) var max_hp: float = 8.0

@export_group("Stamina - SP")
@export_range(0.0, 1000.0) var max_sp: float = 300.0
@export_range(0.0, 100.0) var stamina_regen_rate: float = 25.0
@export_range(0.0, 10.0) var stamina_regen_delay: float = 1.0

@export_group("Chaos - CP")
@export_range(0.0, 100.0) var max_chaos: float = 100.0
@export_range(0.0, 100.0) var chaos_per_hit: float = 20.0

@export_group("Movement")
@export_range(0.0, 100.0) var move_speed: float = 7.0
@export_range(0.0, 100.0) var acceleration: float = 18.0
@export_range(0.0, 100.0) var deceleration: float = 24.0

@export_group("Dash")
@export_range(0.0, 100.0) var dash_distance: float = 4.0
@export_range(0.01, 1.0) var dash_duration: float = 0.25
@export_range(0.0, 1000.0) var dash_cost: float = 50
# Nho nut dash trong mot khoang ngan de tranh mat lenh giua hai lan cap nhat.
@export_range(0.0, 1.0) var dash_buffer_duration: float = 0.1

@export_group("Hit Reaction")
@export_range(0.01, 5.0) var hit_duration: float = 0.6
