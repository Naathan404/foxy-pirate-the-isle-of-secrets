class_name TortugaWeaponDetails
extends Control

const TILE_SCENE: PackedScene = preload("res://gameplay/forge/tortuga_stat_tile.tscn")
const BODY_FONT: FontFile = preload("res://assets/fonts/unifont-17.0.03.otf")
const PERCENT_SCALE := 100.0
const BASE_MULTIPLIER := 1.0

const STAT_NAMES := [
	"Attack",
	"Crit Damage",
	"Attack Speed",
	"Knockback",
	"Crit Rate",
	"Range",
	"Stagger",
	"Chaos Gain"
]
const FORGE_FIELDS := {
	"damage_multiplier": "Damage",
	"flat_damage": "Flat Damage",
	"attack_speed_multiplier": "Attack Speed",
	"critical_rate_bonus": "Crit Rate",
	"critical_damage_multiplier": "Crit Damage",
	"critical_damage_bonus": "Crit Damage",
	"stagger_multiplier": "Stagger",
	"chaos_gain_multiplier": "Chaos Gain",
	"skill_damage_multiplier": "Skill Damage",
	"knockback_multiplier": "Knockback",
	"projectile_knockback_multiplier": "Projectile Knockback",
	"windup_multiplier": "Startup",
	"recovery_multiplier": "Recovery",
	"range_multiplier": "Attack Range",
	"melee_hitbox_multiplier": "Melee Hitbox",
	"projectile_range_multiplier": "Projectile Range",
	"projectile_speed_multiplier": "Projectile Speed",
	"stamina_cost_multiplier": "SP Cost",
	"stamina_damage_multiplier": "SP Attack Damage",
	"hitbox_multiplier": "Hitbox"
}

@export_group("Stat Layout")
@export_range(1, 4, 1) var stat_column_count := 2
@export_range(80.0, 300.0, 1.0) var stat_column_step := 164.0
@export_range(16.0, 80.0, 1.0) var stat_row_step := 28.0
@export_group("Forge Attribute Rows")
@export_range(16.0, 48.0, 1.0) var forge_row_step := 27.0
@export_range(16.0, 48.0, 1.0) var forge_row_height := 25.0
@export_range(120.0, 500.0, 1.0) var forge_row_width := 344.0
@export_range(8, 32, 1) var forge_font_size := 14
@export var forge_text_color := Color(0.25, 0.13, 0.08)
@export var neutral_row_color := Color(0.76, 0.69, 0.60, 0.45)
@export var beneficial_row_color := Color(0.60, 0.77, 0.55, 0.70)
@export var harmful_row_color := Color(0.88, 0.56, 0.50, 0.70)
@export_range(0, 16, 1) var forge_row_corner_radius := 3
@export_range(0.0, 300.0, 1.0) var minimum_forge_rows_height := 104.0

var _tiles: Array[Control] = []

@onready var description: Label = $Description
@onready var stats_grid: Control = $StatsGrid
@onready var forge_heading: Label = $ForgeHeading
@onready var forge_rows: Control = $ForgeScroll/ForgeRows
@onready var skill_icon: TextureRect = $SkillFrame/SkillIcon
@onready var skill_name: Label = $SkillName
@onready var skill_meta: Label = $SkillMeta
@onready var skill_description: Label = $SkillDescription


func _ready() -> void:
	for index in STAT_NAMES.size():
		var tile := TILE_SCENE.instantiate() as Control
		stats_grid.add_child(tile)
		tile.position = Vector2(
			index % stat_column_count * stat_column_step,
			floori(float(index) / stat_column_count) * stat_row_step
		)
		tile.get_node("Name").text = STAT_NAMES[index]
		_tiles.append(tile)
	set_weapon(null, null)


func set_weapon(data: WeaponData, owned: WeaponInstance) -> void:
	_clear_forge_rows()
	if data == null or data.normal_attack == null:
		description.text = "Select a weapon to view its details."
		for tile in _tiles:
			tile.get_node("Value").text = "--"
		forge_heading.text = "FORGE ATTRIBUTES"
		_add_forge_row("No weapon selected")
		skill_icon.texture = null
		skill_name.text = "No weapon skill"
		skill_meta.text = ""
		skill_description.text = ""
		return
	var forge := owned.forge if owned != null else null
	description.text = data.description
	description.tooltip_text = data.description
	_set_stats(data, forge, owned)
	_set_forge(data, forge)
	_set_skill(data.secondary_attack)


func _set_stats(data: WeaponData, forge: WeaponForge, owned: WeaponInstance) -> void:
	var attack := data.normal_attack
	var speed := forge.attack_speed_multiplier if forge != null else BASE_MULTIPLIER
	var damage := attack.damage_hp
	if forge != null:
		var multiplier := forge.damage_multiplier
		if attack.stamina_cost > 0.0 and forge.stamina_cost_multiplier > 0.0:
			multiplier *= forge.stamina_damage_multiplier
		damage = maxf(0.0, damage * multiplier + forge.flat_damage)
	var crit := clampf(
		data.critical_rate + (forge.critical_rate_bonus if forge != null else 0.0), 0.0, 1.0
	)
	var knockback := forge.knockback_multiplier if forge != null else BASE_MULTIPLIER
	var crit_damage := data.critical_damage_multiplier
	var stagger := data.stagger_damage * attack.stagger_multiplier
	var chaos_gain := data.chaos_per_hit
	if forge != null:
		crit_damage = maxf(
			1.0, crit_damage * forge.critical_damage_multiplier + forge.critical_damage_bonus
		)
		stagger *= forge.stagger_multiplier
		chaos_gain *= forge.chaos_gain_multiplier
	var reach := attack.range_units
	if forge != null:
		reach *= forge.range_multiplier
		if attack.delivery_type == AttackData.DeliveryType.PROJECTILE:
			reach *= forge.projectile_range_multiplier
			knockback *= forge.projectile_knockback_multiplier
	if owned != null:
		chaos_gain = owned.get_chaos_gain()
	var values := [
		_number(damage),
		"x" + _number(crit_damage),
		_signed((speed - BASE_MULTIPLIER) * PERCENT_SCALE) + "%",
		"x" + _number(knockback),
		_number(crit * PERCENT_SCALE) + "%",
		_number(reach),
		_number(stagger),
		_number(chaos_gain) + " CP"
	]
	for index in values.size():
		_tiles[index].get_node("Value").text = values[index]


func _set_forge(data: WeaponData, forge: WeaponForge) -> void:
	forge_heading.text = "FORGE ATTRIBUTES"
	if forge == null:
		_add_forge_row("No forge applied")
		return
	forge_heading.text = "FORGE / " + forge.display_name
	forge_heading.tooltip_text = forge.description
	var count := 0
	for field: String in FORGE_FIELDS:
		var value := float(forge.get(field))
		var additive := field in ["flat_damage", "critical_rate_bonus", "critical_damage_bonus"]
		if is_equal_approx(value, 0.0 if additive else BASE_MULTIPLIER):
			continue
		var effect := (
			_signed(value)
			if field == "flat_damage"
			else (
				_signed((value if additive else value - BASE_MULTIPLIER) * PERCENT_SCALE)
				+ (" pp" if additive else "%")
			)
		)
		var benefit := value - (0.0 if additive else BASE_MULTIPLIER)
		if field in ["windup_multiplier", "recovery_multiplier", "stamina_cost_multiplier"]:
			benefit = -benefit
		if (
			field == "projectile_speed_multiplier"
			and data.normal_attack.delivery_type != AttackData.DeliveryType.PROJECTILE
		):
			continue
		if (
			field == "melee_hitbox_multiplier"
			and data.normal_attack.delivery_type != AttackData.DeliveryType.MELEE
		):
			continue
		_add_forge_row(effect + " " + FORGE_FIELDS[field], benefit)
		count += 1
	if count == 0:
		_add_forge_row("Unmodified weapon stats")


func _set_skill(skill: AttackData) -> void:
	if skill == null:
		skill_icon.texture = null
		skill_name.text = "No weapon skill"
		skill_meta.text = ""
		skill_description.text = ""
		return
	skill_icon.texture = skill.skill_icon
	skill_name.text = skill.display_name if not skill.display_name.is_empty() else "Weapon Skill"
	skill_meta.text = _number(skill.charge_seconds) + "s charge" if skill.hold_to_charge else ""
	skill_description.text = skill.description
	skill_description.tooltip_text = skill.description


func _clear_forge_rows() -> void:
	for child in forge_rows.get_children():
		forge_rows.remove_child(child)
		child.queue_free()
	forge_rows.custom_minimum_size.y = minimum_forge_rows_height


func _add_forge_row(message: String, benefit: float = 0.0) -> void:
	var label := Label.new()
	label.text = "  " + message
	label.tooltip_text = message
	label.position = Vector2(0, forge_rows.get_child_count() * forge_row_step)
	label.size = Vector2(forge_row_width, forge_row_height)
	label.add_theme_font_override("font", BODY_FONT)
	label.add_theme_font_size_override("font_size", forge_font_size)
	label.add_theme_color_override("font_color", forge_text_color)
	var style := StyleBoxFlat.new()
	style.bg_color = neutral_row_color
	if benefit > 0.0:
		style.bg_color = beneficial_row_color
	elif benefit < 0.0:
		style.bg_color = harmful_row_color
	style.set_corner_radius_all(forge_row_corner_radius)
	label.add_theme_stylebox_override("normal", style)
	forge_rows.add_child(label)
	forge_rows.custom_minimum_size.y = maxf(
		minimum_forge_rows_height, forge_rows.get_child_count() * forge_row_step
	)


func _number(value: float) -> String:
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")


func _signed(value: float) -> String:
	return ("+" if value >= 0.0 else "") + _number(value)
