class_name TortugaForgePopup
extends Control
## Modal shown after a Forge roll has been paid: two different results side by side, each with
## its description and a now -> new comparison of every affected stat. The panel decides what
## happens with the choice; this popup only reports which card was picked.

signal option_chosen(index: int)

const ROW_SCENE: PackedScene = preload("res://gameplay/forge/tortuga_stat_row.tscn")
const OPTION_COUNT := 2
const OPTION_NAMES := ["Option I", "Option II"]
const BASE_MULTIPLIER := 1.0
const PERCENT_SCALE := 100.0
const CARD_STAGGER_SECONDS := 0.08

@export var notice_color: Color = Color(0.95, 0.56, 0.5)
@export var subtitle_color: Color = Color(0.77, 0.61, 0.53)

var _choosing: bool = false

@onready var _subtitle: Label = %Subtitle
@onready var _cards: Array[Control] = [%CardA, %CardB]


func _ready() -> void:
	for index in range(_cards.size()):
		var button := _choose_button(_cards[index])
		button.pressed.connect(_on_choose.bind(index))
		InventoryHoverFeedback.attach(button)
	hide()


## `payment` describes what was already paid, so the player knows closing is not free.
func show_choices(weapon: WeaponInstance, choices: Array[WeaponForge], payment: String) -> void:
	if weapon == null or weapon.definition == null or choices.size() != OPTION_COUNT:
		return
	_subtitle.text = (
		"Paid %s. Keep one result; it replaces %s." % [payment, weapon.forge.display_name]
		if weapon.forge != null
		else "Paid %s. Keep one result." % payment
	)
	_subtitle.add_theme_color_override("font_color", subtitle_color)
	for index in range(OPTION_COUNT):
		_fill_card(_cards[index], index, weapon, choices[index])
		_choose_button(_cards[index]).disabled = false
	_choosing = true
	show()
	for index in range(_cards.size()):
		InventoryMenuFx.pop(
			_cards[index], InventoryMenuFx.STAGGER_FROM_SCALE, index * CARD_STAGGER_SECONDS
		)
		InventoryMenuFx.burst(_cards[index].get_node("Icon") as Control)
	_choose_button(_cards[0]).grab_focus.call_deferred()


## Explains why the popup cannot be dismissed yet (Esc, Back or a failed apply).
func show_notice(text: String) -> void:
	_subtitle.text = text
	_subtitle.add_theme_color_override("font_color", notice_color)
	InventoryMenuFx.shake(_subtitle)


func close() -> void:
	_choosing = false
	hide()


func _fill_card(card: Control, index: int, weapon: WeaponInstance, forge: WeaponForge) -> void:
	(card.get_node("Icon") as TextureRect).texture = weapon.definition.icon
	var title := card.get_node("Name") as Label
	title.text = forge.display_name
	title.tooltip_text = forge.display_name
	var current := weapon.forge.display_name if weapon.forge != null else ""
	(card.get_node("Kind") as Label).text = (
		"%s  ·  replaces %s" % [OPTION_NAMES[index], current]
		if not current.is_empty()
		else "%s  ·  first forge" % OPTION_NAMES[index]
	)
	var body := card.get_node("StatsScroll/Margin/Body") as Control
	var description := forge.description.strip_edges()
	(body.get_node("Description") as Label).text = (
		description if not description.is_empty() else "No description."
	)
	var rows := body.get_node("Rows") as VBoxContainer
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var values := _comparison_rows(weapon, forge)
	# Changed stats first; unchanged ones stay listed afterwards for reference.
	var ordered: Array[Dictionary] = []
	for value: Dictionary in values:
		if value.trend != 0:
			ordered.append(value)
	for value: Dictionary in values:
		if value.trend == 0:
			ordered.append(value)
	var better := 0
	var worse := 0
	for value: Dictionary in ordered:
		var row := ROW_SCENE.instantiate() as TortugaStatRow
		rows.add_child(row)
		row.set_comparison(value.title, value.before, value.after, value.trend)
		if value.trend > 0:
			better += 1
		elif value.trend < 0:
			worse += 1
	(card.get_node("StatsScroll") as ScrollContainer).scroll_vertical = 0
	(card.get_node("Summary") as Label).text = (
		"▲ %d better  ·  ▼ %d worse" % [better, worse] if better + worse > 0 else "No stat changes"
	)


func _choose_button(card: Control) -> Button:
	return card.get_node("Choose") as Button


func _on_choose(index: int) -> void:
	if not _choosing:
		return
	# One choice per roll: lock both cards until the panel answers.
	_choosing = false
	for card: Control in _cards:
		_choose_button(card).disabled = true
	option_chosen.emit(index)


## Re-enables the cards when the panel could not apply the choice.
func allow_retry() -> void:
	_choosing = true
	for card: Control in _cards:
		_choose_button(card).disabled = false


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
		clampf(data.critical_rate + _bonus(old, "critical_rate_bonus"), 0.0, 1.0) * PERCENT_SCALE,
		clampf(data.critical_rate + chosen.critical_rate_bonus, 0.0, 1.0) * PERCENT_SCALE,
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
	elif chosen.skill_damage_multiplier != BASE_MULTIPLIER:
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
	elif chosen.melee_hitbox_multiplier != BASE_MULTIPLIER:
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
			"Proj. knockback",
			_value(old, "projectile_knockback_multiplier"),
			chosen.projectile_knockback_multiplier,
			"%.2fx"
		)
	elif chosen.projectile_speed_multiplier != BASE_MULTIPLIER:
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
	elif chosen.stamina_damage_multiplier != BASE_MULTIPLIER:
		_add_na(result, "Stamina damage")
	return result


func _normal_damage(attack: AttackData, forge: WeaponForge) -> float:
	if forge == null:
		return attack.damage_hp
	var multiplier := forge.damage_multiplier
	if attack.stamina_cost > 0.0 and forge.stamina_cost_multiplier > 0.0:
		multiplier *= forge.stamina_damage_multiplier
	return maxf(0.0, attack.damage_hp * multiplier + forge.flat_damage)


## Lower values are better for windup, recovery and Stamina cost.
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
	return float(forge.get(property)) if forge != null else BASE_MULTIPLIER


func _bonus(forge: WeaponForge, property: String) -> float:
	return float(forge.get(property)) if forge != null else 0.0
