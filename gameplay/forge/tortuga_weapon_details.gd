class_name TortugaWeaponDetails
extends ScrollContainer
## Scrollable weapon sheet for Master Tortuga's panel, laid out like the Inventory Weapon page:
## description, icon stat rows, the active Forge and the weapon skill.
##
## An uncrafted blueprint shows base values; an owned weapon shows its active Forge. Stat
## names, icons and Forge field labels come from InventoryWeaponsTab so both screens agree.

const STAT := InventoryWeaponsTab.Stat
const PERCENT_SCALE := 100.0
const BASE_MULTIPLIER := 1.0
const NO_VALUE := "--"

@export var skill_action: StringName = &"secondary_attack"
@export var positive_forge_color: Color = Color(0.66, 0.85, 0.58)
@export var negative_forge_color: Color = Color(0.95, 0.56, 0.5)
@export_range(12, 30, 1) var stat_font_size: int = 18
@export_range(16, 40, 1) var stat_icon_size: int = 24
@export_range(0, 40, 1) var stat_icon_gap: int = 10
@export_range(1, 8, 1) var stat_underline_height: int = 3

var _stat_values: Dictionary[int, Label] = {}

@onready var _description: Label = %Description
@onready var _stats_list: VBoxContainer = %StatsList
@onready var _forge_heading: Label = %ForgeHeading
@onready var _forge_rows: VBoxContainer = %ForgeRows
@onready var _skill_icon: TextureRect = %SkillIcon
@onready var _skill_name: Label = %SkillName
@onready var _skill_meta: Label = %SkillMeta
@onready var _skill_description: Label = %SkillDescription


func _ready() -> void:
	_build_stat_rows()
	set_weapon(null, null)


func set_weapon(data: WeaponData, owned: WeaponInstance) -> void:
	scroll_vertical = 0
	_clear_forge_rows()
	if data == null or data.normal_attack == null:
		_description.text = "Select a weapon to view its details."
		for label: Label in _stat_values.values():
			label.text = NO_VALUE
		_forge_heading.text = "Forge"
		_add_forge_row("No weapon selected.", 0.0)
		_set_skill(null)
		return
	var forge := owned.forge if owned != null else null
	var text := data.description.strip_edges()
	_description.text = text if not text.is_empty() else "No description yet."
	_set_stats(data, forge, owned)
	_set_forge(data, forge, owned != null)
	_set_skill(data.secondary_attack)


func _set_stats(data: WeaponData, forge: WeaponForge, owned: WeaponInstance) -> void:
	var attack := data.normal_attack
	var damage := attack.damage_hp
	var speed := BASE_MULTIPLIER
	var crit_rate := data.critical_rate
	var crit_damage := data.critical_damage_multiplier
	var knockback := BASE_MULTIPLIER
	var stagger := data.stagger_damage * attack.stagger_multiplier
	var chaos_gain := data.chaos_per_hit
	var reach := attack.range_units
	if forge != null:
		var multiplier := forge.damage_multiplier
		if attack.stamina_cost > 0.0 and forge.stamina_cost_multiplier > 0.0:
			multiplier *= forge.stamina_damage_multiplier
		damage = maxf(0.0, damage * multiplier + forge.flat_damage)
		speed = forge.attack_speed_multiplier
		crit_rate += forge.critical_rate_bonus
		crit_damage = maxf(
			1.0, crit_damage * forge.critical_damage_multiplier + forge.critical_damage_bonus
		)
		knockback = forge.knockback_multiplier
		stagger *= forge.stagger_multiplier
		chaos_gain *= forge.chaos_gain_multiplier
		reach *= forge.range_multiplier
		if attack.delivery_type == AttackData.DeliveryType.PROJECTILE:
			reach *= forge.projectile_range_multiplier
			knockback *= forge.projectile_knockback_multiplier
	if owned != null:
		chaos_gain = owned.get_chaos_gain()
	_stat_values[STAT.DAMAGE].text = InventoryMenuFormat.number(damage)
	_stat_values[STAT.ATTACK_SPEED].text = (
		InventoryMenuFormat.signed((speed - BASE_MULTIPLIER) * PERCENT_SCALE) + "%"
	)
	_stat_values[STAT.CRIT_RATE].text = (
		InventoryMenuFormat.number(clampf(crit_rate, 0.0, 1.0) * PERCENT_SCALE) + "%"
	)
	_stat_values[STAT.CRIT_DAMAGE].text = "x" + InventoryMenuFormat.number(crit_damage)
	_stat_values[STAT.CHAOS_GAIN].text = InventoryMenuFormat.number(chaos_gain) + " / hit"
	_stat_values[STAT.RANGE].text = InventoryMenuFormat.number(reach)
	_stat_values[STAT.KNOCKBACK].text = "x" + InventoryMenuFormat.number(knockback)
	_stat_values[STAT.STAGGER].text = InventoryMenuFormat.number(stagger)


func _set_forge(data: WeaponData, forge: WeaponForge, is_owned: bool) -> void:
	_forge_heading.tooltip_text = ""
	if forge == null:
		_forge_heading.text = "Forge"
		_add_forge_row(
			"No forge applied." if is_owned else "Craft the weapon before forging it.", 0.0
		)
		return
	_forge_heading.text = "Forge  ·  " + forge.display_name
	_forge_heading.tooltip_text = forge.description
	var count := 0
	for field: String in InventoryWeaponsTab.FORGE_FIELDS:
		if not _forge_field_applies(field, data.normal_attack):
			continue
		var value := float(forge.get(field))
		var additive: bool = field in InventoryWeaponsTab.ADDITIVE_FORGE_FIELDS
		var neutral := 0.0 if additive else BASE_MULTIPLIER
		if is_equal_approx(value, neutral):
			continue
		var effect := (
			InventoryMenuFormat.signed(value)
			if field == "flat_damage"
			else (
				InventoryMenuFormat.signed((value - neutral) * PERCENT_SCALE)
				+ (" pp" if additive else "%")
			)
		)
		var benefit := value - neutral
		if field in InventoryWeaponsTab.COST_FORGE_FIELDS:
			benefit = -benefit
		_add_forge_row("%s %s" % [effect, InventoryWeaponsTab.FORGE_FIELDS[field]], benefit)
		count += 1
	if count == 0:
		_add_forge_row("No stat changes.", 0.0)


func _forge_field_applies(field: String, attack: AttackData) -> bool:
	match field:
		"projectile_speed_multiplier", "projectile_range_multiplier", "projectile_knockback_multiplier":
			return attack.delivery_type == AttackData.DeliveryType.PROJECTILE
		"melee_hitbox_multiplier":
			return attack.delivery_type == AttackData.DeliveryType.MELEE
	return true


func _set_skill(skill: AttackData) -> void:
	if skill == null:
		_skill_icon.texture = null
		_skill_name.text = "No weapon skill"
		_skill_meta.text = ""
		_skill_description.text = ""
		return
	_skill_icon.texture = skill.skill_icon
	_skill_name.text = skill.display_name if not skill.display_name.is_empty() else "Weapon Skill"
	_skill_name.tooltip_text = _skill_name.text
	var parts: PackedStringArray = ["Use: %s" % InventoryMenuFormat.action_key(skill_action)]
	if skill.hold_to_charge:
		parts.append("Hold %ss" % InventoryMenuFormat.number(skill.charge_seconds))
	if skill.cooldown_seconds > 0.0:
		parts.append("CD %ss" % InventoryMenuFormat.number(skill.cooldown_seconds))
	if skill.stamina_cost > 0.0:
		parts.append("%s SP" % InventoryMenuFormat.number(skill.stamina_cost))
	_skill_meta.text = "  ·  ".join(parts)
	_skill_description.text = skill.description.strip_edges()


func _build_stat_rows() -> void:
	var line := AtlasTexture.new()
	line.atlas = InventoryWeaponsTab.STAT_SHEET
	line.region = InventoryWeaponsTab.STAT_LINE_REGION
	for stat: int in InventoryWeaponsTab.STAT_ICON_REGIONS:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		row.tooltip_text = InventoryWeaponsTab.STAT_TOOLTIPS[stat]
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		var content := HBoxContainer.new()
		content.add_theme_constant_override("separation", stat_icon_gap)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(content)
		var icon := TextureRect.new()
		var region := AtlasTexture.new()
		region.atlas = InventoryWeaponsTab.STAT_SHEET
		region.region = InventoryWeaponsTab.STAT_ICON_REGIONS[stat]
		icon.texture = region
		icon.custom_minimum_size = Vector2.ONE * stat_icon_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(icon)
		var name_label := Label.new()
		name_label.text = InventoryWeaponsTab.STAT_NAMES[stat]
		name_label.theme_type_variation = &"MutedLabel"
		name_label.add_theme_font_size_override("font_size", stat_font_size)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(name_label)
		var value_label := Label.new()
		value_label.text = NO_VALUE
		value_label.theme_type_variation = &"BodyLabel"
		value_label.add_theme_font_size_override("font_size", stat_font_size)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		content.add_child(value_label)
		var underline := TextureRect.new()
		underline.texture = line
		underline.custom_minimum_size.y = stat_underline_height
		underline.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(underline)
		_stats_list.add_child(row)
		_stat_values[stat] = value_label


func _add_forge_row(text: String, benefit: float) -> void:
	var label := Label.new()
	# A leading sign keeps gains and penalties distinct without relying on color.
	label.text = ("▲ " if benefit > 0.0 else "▼ " if benefit < 0.0 else "• ") + text
	label.theme_type_variation = &"BodyLabel"
	label.add_theme_font_size_override("font_size", stat_font_size - 1)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if benefit > 0.0:
		label.add_theme_color_override("font_color", positive_forge_color)
	elif benefit < 0.0:
		label.add_theme_color_override("font_color", negative_forge_color)
	_forge_rows.add_child(label)


func _clear_forge_rows() -> void:
	for child in _forge_rows.get_children():
		_forge_rows.remove_child(child)
		child.queue_free()
