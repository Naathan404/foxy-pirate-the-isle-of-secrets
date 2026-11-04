class_name TortugaForgePopup
extends Control

signal option_chosen(index: int)

const ROW_SCENE: PackedScene = preload("res://gameplay/forge/tortuga_stat_row.tscn")
const ROW_HEIGHT := 32.0

@onready var window: Control = $Window
@onready var cards: Array[Control] = [$Window/CardA, $Window/CardB]


func _ready() -> void:
	window.pivot_offset = window.size * 0.5
	get_viewport().size_changed.connect(_fit_window)
	for index in cards.size():
		cards[index].get_node("Choose").pressed.connect(_on_choose.bind(index))
	_fit_window()
	hide()


func show_choices(weapon: WeaponInstance, choices: Array[WeaponForge]) -> void:
	if weapon == null or choices.size() != 2:
		return
	$Window/Subtitle.text = "Payment complete. Select one result to continue."
	for index in 2:
		_fill_card(cards[index], weapon, choices[index])
	show()
	_fit_window()


func _fill_card(card: Control, weapon: WeaponInstance, forge: WeaponForge) -> void:
	card.get_node("Name").text = forge.display_name
	card.get_node("Description").text = forge.description
	var rows := card.get_node("StatsScroll/Rows") as Control
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var values := _comparison_rows(weapon, forge)
	rows.custom_minimum_size.y = maxf(250.0, values.size() * ROW_HEIGHT)
	for index in values.size():
		var value: Dictionary = values[index]
		var row := ROW_SCENE.instantiate() as Control
		rows.add_child(row)
		row.position = Vector2(0, index * ROW_HEIGHT)
		row.call(&"set_comparison", value.title, value.before, value.after, value.trend)


func _comparison_rows(weapon: WeaponInstance, chosen: WeaponForge) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var data := weapon.definition
	var attack := data.normal_attack
	var old := weapon.forge
	_add_metric(
		result,
		"Base hit damage",
		_normal_damage(attack, old),
		_normal_damage(attack, chosen),
		"%.1f"
	)
	_add_metric(
		result,
		"Attack speed",
		_value(old, "attack_speed_multiplier"),
		chosen.attack_speed_multiplier,
		"%.2fx"
	)
	_add_metric(
		result,
		"Crit chance",
		clampf(data.critical_rate + _bonus(old, "critical_rate_bonus"), 0.0, 1.0) * 100.0,
		clampf(data.critical_rate + chosen.critical_rate_bonus, 0.0, 1.0) * 100.0,
		"%.0f%%"
	)
	_add_metric(
		result,
		"Crit damage",
		maxf(
			1.0,
			(
				data.critical_damage_multiplier * _value(old, "critical_damage_multiplier")
				+ _bonus(old, "critical_damage_bonus")
			)
		),
		maxf(
			1.0,
			(
				data.critical_damage_multiplier * chosen.critical_damage_multiplier
				+ chosen.critical_damage_bonus
			)
		),
		"%.2fx"
	)
	var old_range := attack.range_units * _value(old, "range_multiplier")
	var new_range := attack.range_units * chosen.range_multiplier
	if attack.delivery_type == AttackData.DeliveryType.PROJECTILE:
		old_range *= _value(old, "projectile_range_multiplier")
		new_range *= chosen.projectile_range_multiplier
	_add_metric(result, "Range", old_range, new_range, "%.2f")
	_add_metric(
		result,
		"Stagger",
		data.stagger_damage * attack.stagger_multiplier * _value(old, "stagger_multiplier"),
		data.stagger_damage * attack.stagger_multiplier * chosen.stagger_multiplier,
		"%.1f"
	)
	_add_metric(
		result,
		"Chaos gain",
		data.chaos_per_hit * _value(old, "chaos_gain_multiplier"),
		data.chaos_per_hit * chosen.chaos_gain_multiplier,
		"%.1f"
	)
	_add_metric(
		result,
		"Knockback",
		(
			_value(old, "knockback_multiplier")
			* (
				_value(old, "projectile_knockback_multiplier")
				if attack.delivery_type == AttackData.DeliveryType.PROJECTILE
				else 1.0
			)
		),
		(
			chosen.knockback_multiplier
			* (
				chosen.projectile_knockback_multiplier
				if attack.delivery_type == AttackData.DeliveryType.PROJECTILE
				else 1.0
			)
		),
		"%.2fx"
	)
	if data.secondary_attack != null:
		_add_metric(
			result,
			"Skill damage",
			_value(old, "skill_damage_multiplier"),
			chosen.skill_damage_multiplier,
			"%.2fx"
		)
	elif chosen.skill_damage_multiplier != 1.0:
		_add_na(result, "Skill damage")
	_add_metric(
		result, "Windup", _value(old, "windup_multiplier"), chosen.windup_multiplier, "%.2fx", true
	)
	_add_metric(
		result,
		"Recovery",
		_value(old, "recovery_multiplier"),
		chosen.recovery_multiplier,
		"%.2fx",
		true
	)
	_add_metric(
		result, "Hitbox", _value(old, "hitbox_multiplier"), chosen.hitbox_multiplier, "%.2fx"
	)
	if attack.delivery_type == AttackData.DeliveryType.MELEE:
		_add_metric(
			result,
			"Melee hitbox",
			_value(old, "melee_hitbox_multiplier"),
			chosen.melee_hitbox_multiplier,
			"%.2fx"
		)
	elif chosen.melee_hitbox_multiplier != 1.0:
		_add_na(result, "Melee hitbox")
	if attack.delivery_type == AttackData.DeliveryType.PROJECTILE:
		_add_metric(
			result,
			"Projectile speed",
			_value(old, "projectile_speed_multiplier"),
			chosen.projectile_speed_multiplier,
			"%.2fx"
		)
		_add_metric(
			result,
			"Projectile knockback",
			_value(old, "projectile_knockback_multiplier"),
			chosen.projectile_knockback_multiplier,
			"%.2fx"
		)
	elif chosen.projectile_speed_multiplier != 1.0:
		_add_na(result, "Projectile speed")
	if attack.stamina_cost > 0.0:
		_add_metric(
			result,
			"Stamina cost",
			attack.stamina_cost * _value(old, "stamina_cost_multiplier"),
			attack.stamina_cost * chosen.stamina_cost_multiplier,
			"%.1f",
			true
		)
		_add_metric(
			result,
			"Stamina damage",
			_value(old, "stamina_damage_multiplier"),
			chosen.stamina_damage_multiplier,
			"%.2fx"
		)
	elif chosen.stamina_damage_multiplier != 1.0:
		_add_na(result, "Stamina damage")
	return result


func _normal_damage(attack: AttackData, forge: WeaponForge) -> float:
	if forge == null:
		return attack.damage_hp
	var multiplier := forge.damage_multiplier
	if attack.stamina_cost > 0.0 and forge.stamina_cost_multiplier > 0.0:
		multiplier *= forge.stamina_damage_multiplier
	return maxf(0.0, attack.damage_hp * multiplier + forge.flat_damage)


func _add_metric(
	rows: Array[Dictionary],
	title: String,
	before: float,
	after: float,
	format: String,
	lower_is_better := false
) -> void:
	var trend := 0
	if not is_equal_approx(before, after):
		trend = 1 if (after < before if lower_is_better else after > before) else -1
	rows.append(
		{"title": title, "before": format % before, "after": format % after, "trend": trend}
	)


func _add_na(rows: Array[Dictionary], title: String) -> void:
	rows.append({"title": title, "before": "-", "after": "N/A", "trend": 0})


func _value(forge: WeaponForge, property: String) -> float:
	return float(forge.get(property)) if forge != null else 1.0


func _bonus(forge: WeaponForge, property: String) -> float:
	return float(forge.get(property)) if forge != null else 0.0


func _flat(forge: WeaponForge) -> float:
	return forge.flat_damage if forge != null else 0.0


func _on_choose(index: int) -> void:
	option_chosen.emit(index)


func _fit_window() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	window.scale = Vector2.ONE * minf(1.0, minf(viewport_size.x / 950.0, viewport_size.y / 590.0))
