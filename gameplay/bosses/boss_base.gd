class_name BossBase
extends CharacterBody3D

signal phase_changed(index: int)
signal fight_started
signal fight_finished
signal damaged(applied_hp: float)
signal reward_spawned(chest: Node3D)

@export var boss_data: BossData
@export_range(1.0, 100.0, 1.0) var activation_range: float = 20.0
@export var reward_chest: PackedScene
@export var respect_ground_boundaries: bool = true
@export_range(0.0, 20.0, 0.1) var grapple_stop_distance: float = 1.0
## Optional strategy node; different bosses can replace the entire behavior.
@export var behavior: BossBehavior

var phase_index: int = 0
var dead: bool = false
var fighting: bool = false
var target: Node3D

@onready var hp: HealthComponent = $HealthComponent
@onready var hurtbox: HurtBox = $HurtBox


func _ready() -> void:
	add_to_group("boss")
	add_to_group("enemy")
	collision_layer = CombatLayers.ENEMY_BODY
	collision_mask = CombatLayers.ENEMY_BODY_MASK
	if respect_ground_boundaries:
		collision_mask |= CombatLayers.PLAYER_BOUNDARY
	hurtbox.actor = self
	hurtbox.team = CombatTeams.ENEMY
	hurtbox.collision_layer = CombatLayers.ENEMY_HURTBOX
	hurtbox.collision_mask = CombatLayers.PLAYER_ATTACK
	if boss_data == null or boss_data.phases.is_empty():
		push_error("BossBase requires boss data with at least one phase")
		set_physics_process(false)
		return
	hp.hp_changed.connect(_on_hp_changed)
	hp.died.connect(_on_death)
	if is_instance_valid(behavior):
		behavior.setup(self)
	_on_boss_setup()
	hp.init(boss_data.max_hp)


func _physics_process(delta: float) -> void:
	var hitstop := get_node_or_null("/root/HitstopController")
	if dead or (hitstop != null and hitstop.is_frozen(self)):
		return
	if not fighting:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if (
			is_instance_valid(player)
			and global_position.distance_to(player.global_position) <= activation_range
		):
			start_fight(player)
	elif not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node3D
	if fighting and is_instance_valid(target):
		_on_fight_tick(delta)
		if is_instance_valid(behavior):
			behavior.fight_tick(delta)


func receive_damage(damage: DamageContext) -> float:
	if dead or damage == null or damage.source == self or damage.source_team == CombatTeams.ENEMY:
		return 0.0
	if not _on_can_receive_damage(damage):
		return 0.0
	if is_instance_valid(behavior) and not behavior.can_receive_damage(damage):
		return 0.0
	if (
		damage.amount_hp > 0.0
		and damage.source_team == CombatTeams.PLAYER
		and damage.source is Node3D
	):
		start_fight(damage.source as Node3D)
	var applied := hp.take_damage(damage.amount_hp)
	if applied > 0.0:
		if is_instance_valid(damage.source) and damage.source.has_signal("combat_activity"):
			damage.source.emit_signal("combat_activity")
		damaged.emit(applied)
	return applied


func start_fight(player: Node3D) -> void:
	if dead or fighting or not is_instance_valid(player):
		return
	target = player
	fighting = true
	_on_fight_started()
	if is_instance_valid(behavior):
		behavior.fight_started()
	fight_started.emit()


func is_defeated() -> bool:
	return dead


func debug_trigger_phase_two() -> bool:
	if not OS.is_debug_build() or dead or boss_data == null or boss_data.phases.size() < 2:
		return false
	if not fighting:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if is_instance_valid(player):
			start_fight(player)
	if phase_index >= 1:
		return false
	var threshold_hp := boss_data.max_hp * boss_data.phases[1].hp_threshold
	if hp.current_hp > threshold_hp:
		hp.take_damage(hp.current_hp - threshold_hp)
	return phase_index >= 1


func apply_charm_grapple(
	source: Node3D, stop_distance: float, pull_speed: float, _stun_seconds: float
) -> StringName:
	if dead or not is_instance_valid(source) or not source.has_method("apply_charm_grapple_pull"):
		return &"miss"
	var pulled := bool(
		source.call(
			"apply_charm_grapple_pull",
			global_position,
			maxf(stop_distance, grapple_stop_distance),
			pull_speed
		)
	)
	return &"actor_pulled_boss" if pulled else &"miss"


func take_damage(amount: float) -> float:
	var damage := DamageContext.new()
	damage.amount_hp = amount
	return receive_damage(damage)


func _on_hp_changed(current: float, maximum: float) -> void:
	if current <= 0.0 or maximum <= 0.0:
		return
	var next := phase_index
	for index in range(phase_index + 1, boss_data.phases.size()):
		if current / maximum <= boss_data.phases[index].hp_threshold:
			next = index
	if next != phase_index:
		phase_index = next
		_on_phase_entered(phase_index)
		if is_instance_valid(behavior):
			behavior.phase_entered(phase_index)
		phase_changed.emit(phase_index)


func _on_death() -> void:
	if dead:
		return
	dead = true
	fighting = false
	velocity = Vector3.ZERO
	hurtbox.enabled = false
	hurtbox.set_deferred("monitorable", false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	_on_fight_ended()
	if is_instance_valid(behavior):
		behavior.fight_ended()
	fight_finished.emit()
	_spawn_reward.call_deferred()


func _on_boss_setup() -> void:
	pass


func _on_fight_started() -> void:
	pass


func _on_can_receive_damage(_damage: DamageContext) -> bool:
	return true


func _on_fight_tick(_delta: float) -> void:
	pass


func _on_phase_entered(_index: int) -> void:
	pass


func _on_fight_ended() -> void:
	pass


func _spawn_reward() -> void:
	if reward_chest == null or not is_inside_tree():
		return
	var chest := reward_chest.instantiate() as Node3D
	get_parent().add_child(chest)
	chest.global_position = global_position
	reward_spawned.emit(chest)
