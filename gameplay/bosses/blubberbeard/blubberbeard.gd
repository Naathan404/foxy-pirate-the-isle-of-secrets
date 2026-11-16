class_name BlubberbeardBehavior
extends BossBehavior

enum State { WAIT, WINDUP, CHARGE, RECOVERY }

const HAZARD = preload("res://gameplay/bosses/blubberbeard/boss_hazard.gd")
const EFFECTS = preload("res://gameplay/bosses/boss_effects.gd")

@export_range(1.0, 100.0, 1.0) var charge_acceleration: float = 50.0
@export_range(1.0, 100.0, 1.0) var recovery_deceleration: float = 32.0

var state: State = State.WAIT
var timer: float = 1.0
var skill: BlubberbeardSkillData
var next_skill: int = 0
var charge_direction := Vector3.ZERO
var charge_speed: float = 0.0
var visual: BlubberbeardVisual
var feedback: BlubberbeardFeedback
var charge_hitbox: HitBox
var sound: AudioStreamPlayer3D
var dust: CPUParticles3D
var charge_warning: MeshInstance3D


func setup(owner_boss: BossBase) -> void:
	super(owner_boss)
	visual = boss.get_node("Sprite3D") as BlubberbeardVisual
	feedback = boss.get_node("Feedback") as BlubberbeardFeedback
	feedback.setup(boss, visual)
	charge_hitbox = boss.get_node("ChargeHitBox") as HitBox
	sound = boss.get_node("Sound") as AudioStreamPlayer3D
	charge_hitbox.actor = boss
	charge_hitbox.team = CombatTeams.ENEMY
	charge_hitbox.collision_layer = CombatLayers.ENEMY_ATTACK
	charge_hitbox.collision_mask = CombatLayers.PLAYER_HURTBOX
	charge_hitbox.damage_applied.connect(_on_charge_damage)
	boss.damaged.connect(_hit_feedback)
	_create_dust()


func fight_started() -> void:
	feedback.fight_started()


func fight_tick(delta: float) -> void:
	if not boss.is_on_floor():
		boss.velocity += boss.get_gravity() * delta
	else:
		boss.velocity.y = 0.0
	timer -= delta
	if state == State.CHARGE:
		charge_speed = move_toward(charge_speed, skill.speed, charge_acceleration * delta)
		_set_horizontal_velocity(charge_direction * charge_speed)
		boss.move_and_slide()
		feedback.charge_tick(delta)
		if timer <= 0.0 or boss.is_on_wall():
			charge_hitbox.end_attack()
			var wall_impact := boss.is_on_wall()
			feedback.charge_end(wall_impact)
			visual.impact(0.2, 0.24)
			if wall_impact:
				charge_speed = 0.0
			_enter_recovery()
		return
	charge_speed = move_toward(charge_speed, 0.0, recovery_deceleration * delta)
	_set_horizontal_velocity(charge_direction * charge_speed)
	boss.move_and_slide()
	if timer > 0.0:
		if state == State.WINDUP:
			visual.windup_progress = 1.0 - clampf(timer / skill.windup, 0.0, 1.0)
			_update_charge_warning()
		return
	match state:
		State.WAIT, State.RECOVERY:
			_choose_skill()
		State.WINDUP:
			_execute_skill()


func _set_horizontal_velocity(horizontal: Vector3) -> void:
	boss.velocity.x = horizontal.x
	boss.velocity.z = horizontal.z


func _choose_skill() -> void:
	var phase := boss.boss_data.phases[boss.phase_index]
	if phase.skills.is_empty():
		timer = 1.0
		return
	skill = phase.skills[next_skill % phase.skills.size()] as BlubberbeardSkillData
	next_skill += 1
	if skill == null:
		push_warning("Blubberbeard requires BlubberbeardSkillData")
		timer = 1.0
		return
	state = State.WINDUP
	timer = skill.windup
	charge_direction = boss.target.global_position - boss.global_position
	charge_direction.y = 0.0
	charge_direction = charge_direction.normalized()
	if charge_direction.is_zero_approx():
		charge_direction = Vector3.FORWARD
	visual.face_direction(charge_direction)
	visual.begin_windup(skill.kind)
	_play_sound(1.2)
	if skill.kind == BlubberbeardSkillData.Kind.POWDER_BARREL:
		_spawn_barrel(boss.target.global_position)
	elif skill.kind == BlubberbeardSkillData.Kind.BELLY_CHARGE:
		_show_charge_warning()


func _execute_skill() -> void:
	_clear_charge_warning()
	match skill.kind:
		BlubberbeardSkillData.Kind.BELLY_CHARGE:
			state = State.CHARGE
			timer = skill.duration
			charge_hitbox.begin_attack(skill.damage, 0, &"boss_charge")
			visual.begin_charge(charge_direction)
			visual.impact(0.15, 0.15)
			dust.emitting = true
			feedback.charge_start()
			_play_sound(0.7)
		BlubberbeardSkillData.Kind.SPIKY_INFLATION:
			feedback.spikes_release()
			visual.impact(0.22, 0.25)
			EFFECTS.shockwave(
				boss.get_parent(), boss.global_position, 2.0, Color(1.0, 0.55, 0.12, 0.8)
			)
			for index in 8:
				_spawn_spike(Vector3(cos(TAU * index / 8.0), 0.0, sin(TAU * index / 8.0)))
			_play_sound(1.6)
			_enter_recovery()
		_:
			_enter_recovery()


func _spawn_barrel(where: Vector3) -> void:
	var hazard := HAZARD.new()
	hazard.source = boss
	hazard.damage = skill.damage
	hazard.radius = skill.radius
	hazard.remaining = skill.windup
	hazard.detonated.connect(_on_barrel_detonated.bind(hazard, skill.radius))
	boss.get_parent().add_child(hazard)
	hazard.global_position = Vector3(where.x, boss.global_position.y + 0.08, where.z)
	hazard.animate_barrel(boss.global_position)


func _spawn_spike(direction: Vector3) -> void:
	var hazard := HAZARD.new()
	hazard.source = boss
	hazard.spike = true
	hazard.direction = direction
	hazard.damage = skill.damage
	hazard.speed = skill.speed
	hazard.remaining = skill.duration
	boss.get_parent().add_child(hazard)
	hazard.global_position = boss.global_position + Vector3.UP * 1.2 + direction * 2.5


func _enter_recovery() -> void:
	state = State.RECOVERY
	timer = skill.recovery + boss.boss_data.phases[boss.phase_index].skill_interval
	dust.emitting = false
	visual.begin_recovery(skill.kind)


func phase_entered(index: int) -> void:
	visual.set_enraged(index > 0)
	feedback.phase_changed()
	visual.impact(0.32, 0.45)
	EFFECTS.shockwave(boss.get_parent(), boss.global_position, 3.0, Color(0.9, 0.2, 0.4, 0.8))
	_play_sound(0.55)


func fight_ended() -> void:
	charge_hitbox.end_attack()
	_clear_charge_warning()
	dust.emitting = false
	feedback.death()
	EFFECTS.shockwave(boss.get_parent(), boss.global_position, 3.0, Color(1.0, 0.65, 0.2, 0.8))
	_play_sound(0.4)
	visual.play_death(boss.queue_free)


func _hit_feedback(_amount: float) -> void:
	if not boss.dead:
		visual.flash_hit()


func _on_barrel_detonated(hazard: Node3D, radius: float) -> void:
	if is_instance_valid(hazard) and not boss.dead:
		feedback.barrel_explosion(hazard.global_position, radius)


func _on_charge_damage(_damage: DamageContext, target: Node, _amount: float) -> void:
	feedback.charge_hit(target)


func _play_sound(pitch: float) -> void:
	if is_instance_valid(sound):
		sound.pitch_scale = pitch
		sound.play()


func _show_charge_warning() -> void:
	_clear_charge_warning()
	charge_warning = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	var travel := skill.speed * skill.duration
	var length := travel + 5.4
	mesh.size = Vector3(5.4, 0.04, length)
	charge_warning.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.1, 0.05, 0.2)
	charge_warning.material_override = material
	boss.add_child(charge_warning)
	charge_warning.position = charge_direction * travel * 0.5 + Vector3.UP * 0.08
	charge_warning.rotation.y = atan2(charge_direction.x, charge_direction.z)
	for side in [-1.0, 1.0]:
		var border := MeshInstance3D.new()
		var border_mesh := BoxMesh.new()
		border_mesh.size = Vector3(0.12, 0.05, length)
		border.mesh = border_mesh
		var border_material := StandardMaterial3D.new()
		border_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		border_material.albedo_color = Color(1.0, 0.15, 0.05)
		border.material_override = border_material
		charge_warning.add_child(border)
		border.position = Vector3(side * 2.7, 0.03, 0)


func _update_charge_warning() -> void:
	if is_instance_valid(charge_warning):
		var material := charge_warning.material_override as StandardMaterial3D
		material.albedo_color.a = 0.15 + 0.2 * visual.windup_progress


func _clear_charge_warning() -> void:
	if is_instance_valid(charge_warning):
		charge_warning.queue_free()
	charge_warning = null


func _create_dust() -> void:
	dust = CPUParticles3D.new()
	dust.name = "ChargeDust"
	dust.emitting = false
	dust.amount = 48
	dust.lifetime = 0.45
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	dust.emission_sphere_radius = 1.8
	dust.local_coords = false
	dust.direction = Vector3.UP
	dust.spread = 75.0
	dust.initial_velocity_min = 0.5
	dust.initial_velocity_max = 3.0
	dust.gravity = Vector3(0, -2, 0)
	dust.scale_amount_min = 0.15
	dust.scale_amount_max = 0.4
	dust.color = Color(0.8, 0.7, 0.48, 0.75)
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	dust.mesh = mesh
	boss.add_child(dust)
	dust.position.y = 0.2
