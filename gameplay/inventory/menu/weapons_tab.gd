class_name InventoryWeaponsTab
extends Control
## Weapon page: the equipped weapon, owned weapon instances, the weapon skill and live stats.
## Ownership, forging and equip validation remain in WeaponController.

enum Stat { DAMAGE, ATTACK_SPEED, CRIT_RATE, CRIT_DAMAGE, CHAOS_GAIN, RANGE, KNOCKBACK, STAGGER }

const SLOT_SCENE: PackedScene = preload("res://gameplay/inventory/menu/catalog_slot.tscn")
const STAT_SHEET: Texture2D = preload("res://assets/ui/HUD_Fox/Weapons/WeaponStat.png")
const EQUIPPED_BADGE: Texture2D = preload("res://assets/ui/HUD_Fox/Weapons/Deco_4.png")
const GRID_COLUMNS := 4
const MIN_VISIBLE_ROWS := 3
const PERCENT_SCALE := 100.0
const BASE_MULTIPLIER := 1.0
const NO_VALUE := "--"
## Icon rows and the ruled line inside WeaponStat.png (source pixels).
const STAT_ICON_REGIONS := {
	Stat.DAMAGE: Rect2(0, 0, 72, 48),
	Stat.ATTACK_SPEED: Rect2(0, 54, 72, 38),
	Stat.CRIT_RATE: Rect2(0, 94, 72, 44),
	Stat.CRIT_DAMAGE: Rect2(0, 140, 72, 48),
	Stat.CHAOS_GAIN: Rect2(0, 188, 72, 40),
	Stat.RANGE: Rect2(0, 228, 72, 45),
	Stat.KNOCKBACK: Rect2(0, 273, 72, 45),
	Stat.STAGGER: Rect2(0, 322, 72, 52),
}
const STAT_LINE_REGION := Rect2(90, 41, 481, 9)
const STAT_NAMES := {
	Stat.DAMAGE: "Damage",
	Stat.ATTACK_SPEED: "Attack Speed",
	Stat.CRIT_RATE: "Crit Rate",
	Stat.CRIT_DAMAGE: "Crit Damage",
	Stat.CHAOS_GAIN: "Chaos Gain",
	Stat.RANGE: "Range",
	Stat.KNOCKBACK: "Knockback",
	Stat.STAGGER: "Stagger",
}
const STAT_TOOLTIPS := {
	Stat.DAMAGE: "Normal attack damage with forge applied. Combo steps and charms apply on hit.",
	Stat.ATTACK_SPEED: "Forge attack speed bonus.",
	Stat.CRIT_RATE: "Chance for a critical hit, forge included.",
	Stat.CRIT_DAMAGE: "Critical hit multiplier, forge included.",
	Stat.CHAOS_GAIN: "Chaos points gained per confirmed enemy hit.",
	Stat.RANGE: "Normal attack reach in world units, forge included.",
	Stat.KNOCKBACK: "Forge knockback multiplier.",
	Stat.STAGGER: "Base stagger with forge applied; combo steps can scale it.",
}
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
	"hitbox_multiplier": "Hitbox",
}
const ADDITIVE_FORGE_FIELDS := ["flat_damage", "critical_rate_bonus", "critical_damage_bonus"]
## Lower is better for these multipliers.
const COST_FORGE_FIELDS := ["windup_multiplier", "recovery_multiplier", "stamina_cost_multiplier"]

@export_range(1.0, 1.3, 0.01) var current_weapon_lift: float = 1.03
@export_range(0, 40, 1) var stat_icon_gap: int = 10
@export_range(1, 8, 1) var stat_underline_height: int = 3
@export var skill_action: StringName = &"secondary_attack"
@export var positive_forge_color: Color = Color(0.66, 0.85, 0.58)
@export var negative_forge_color: Color = Color(0.95, 0.56, 0.5)
@export_range(12, 30, 1) var stat_font_size: int = 18
@export_range(16, 40, 1) var stat_icon_size: int = 24
@export_range(1.0, 1.3, 0.01) var equip_feedback_scale: float = 1.1
@export_range(0.05, 0.5, 0.01, "suffix:s") var equip_feedback_seconds: float = 0.2

var weapons: WeaponController

var _selection: WeaponInstance
var _owned: Array[WeaponInstance] = []
var _slots: Array[InventoryCatalogSlot] = []
var _stat_values: Dictionary[Stat, Label] = {}
var _dirty: bool = true
var _feedback_tween: Tween

@onready var _grid: GridContainer = %Grid
@onready var _counter_label: Label = %CounterLabel
@onready var _current_button: Button = %CurrentWeapon
@onready var _current_icon: TextureRect = %CurrentIcon
@onready var _current_name: Label = %CurrentName
@onready var _current_state: Label = %CurrentState
@onready var _big_icon: TextureRect = %BigIcon
@onready var _weapon_name: Label = %WeaponName
@onready var _weapon_kind: Label = %WeaponKind
@onready var _details_scroll: ScrollContainer = %DetailsScroll
@onready var _description: Label = %Description
@onready var _stats_list: VBoxContainer = %StatsList
@onready var _forge_heading: Label = %ForgeHeading
@onready var _forge_rows: VBoxContainer = %ForgeRows
@onready var _skill_icon: TextureRect = %SkillIcon
@onready var _skill_name: Label = %SkillName
@onready var _skill_meta: Label = %SkillMeta
@onready var _skill_scroll: ScrollContainer = %SkillScroll
@onready var _skill_description: Label = %SkillDescription
@onready var _action_hint: Label = %ActionHint
@onready var _equip_button: Button = %EquipButton


func _ready() -> void:
	_build_stat_rows()
	_equip_button.pressed.connect(_on_equip_pressed)
	_current_button.pressed.connect(_select_equipped)
	visibility_changed.connect(_on_visibility_changed)
	InventoryHoverFeedback.attach(_equip_button)
	InventoryHoverFeedback.attach(_current_button, null, current_weapon_lift)


func setup(controller: WeaponController) -> void:
	if is_instance_valid(weapons):
		return
	weapons = controller
	if is_instance_valid(weapons):
		weapons.weapon_changed.connect(_on_weapon_changed)
		weapons.collection_changed.connect(_request_refresh)
	_request_refresh()


func refresh() -> void:
	_dirty = false
	_owned = weapons.get_owned_weapons() if is_instance_valid(weapons) else []
	if not _owned.has(_selection):
		_selection = null
		if is_instance_valid(weapons) and _owned.has(weapons.equipped):
			_selection = weapons.equipped
		elif not _owned.is_empty():
			_selection = _owned[0]
	_refresh_grid()
	_refresh_equipped()
	_refresh_details()


## Entrance animation played by the menu when this page appears.
func play_intro() -> void:
	InventoryMenuFx.stagger_in(_slots)
	InventoryMenuFx.pop(_big_icon, InventoryMenuFx.ICON_POP_FROM_SCALE)
	InventoryMenuFx.pop(_current_icon, InventoryMenuFx.ICON_POP_FROM_SCALE)


func focus_default() -> void:
	var index := _owned.find(_selection)
	var target: Control = _slots[index] if index >= 0 else _current_button
	target.grab_focus.call_deferred()


func _request_refresh() -> void:
	if is_visible_in_tree():
		refresh()
	else:
		_dirty = true


func _on_visibility_changed() -> void:
	if is_visible_in_tree() and _dirty:
		refresh()


func _on_weapon_changed(_weapon: WeaponInstance) -> void:
	_request_refresh()


func _refresh_grid() -> void:
	var rows: int = maxi(MIN_VISIBLE_ROWS, ceili(float(_owned.size()) / GRID_COLUMNS))
	var cell_count: int = rows * GRID_COLUMNS
	while _slots.size() < cell_count:
		var slot := SLOT_SCENE.instantiate() as InventoryCatalogSlot
		_grid.add_child(slot)
		slot.pressed.connect(_select_index.bind(_slots.size()))
		_slots.append(slot)
	for index in range(_slots.size()):
		var slot := _slots[index]
		slot.visible = index < cell_count
		if index >= _owned.size():
			slot.present_placeholder()
			continue
		var weapon := _owned[index]
		var equipped := _is_equipped(weapon)
		slot.present(_icon(weapon), true, false, EQUIPPED_BADGE if equipped else null)
		slot.set_selected(weapon == _selection)
		slot.tooltip_text = _name(weapon) + (" (equipped)" if equipped else "")

	var collection_size: int = 0
	if is_instance_valid(weapons):
		for entry: WeaponCollectionEntry in weapons.collection:
			if entry != null and entry.definition != null:
				collection_size += 1
	_counter_label.text = "%d/%d" % [_owned.size(), maxi(collection_size, _owned.size())]


func _refresh_equipped() -> void:
	var equipped := weapons.equipped if is_instance_valid(weapons) else null
	_current_icon.texture = _icon(equipped)
	_current_name.text = _name(equipped) if equipped != null else "No weapon"
	_current_state.text = "Equipped" if equipped != null else "Nothing equipped"
	_current_button.tooltip_text = (
		"Show the equipped weapon" if equipped != null else "No weapon equipped"
	)


func _select_index(index: int) -> void:
	if index < _owned.size():
		var changed := _owned[index] != _selection
		_selection = _owned[index]
		refresh()
		if changed:
			InventoryMenuFx.pop(_big_icon, InventoryMenuFx.ICON_POP_FROM_SCALE)


func _select_equipped() -> void:
	if is_instance_valid(weapons) and _owned.has(weapons.equipped):
		var changed := weapons.equipped != _selection
		_selection = weapons.equipped
		refresh()
		if changed:
			InventoryMenuFx.pop(_big_icon, InventoryMenuFx.ICON_POP_FROM_SCALE)


func _refresh_details() -> void:
	_action_hint.text = ""
	_details_scroll.scroll_vertical = 0
	_skill_scroll.scroll_vertical = 0
	_clear_forge_rows()
	if _selection == null or _selection.definition == null:
		_show_empty_details()
		return

	var data := _selection.definition
	var equipped := _is_equipped(_selection)
	_big_icon.texture = data.icon
	_weapon_name.text = _name(_selection)
	_weapon_name.tooltip_text = _weapon_name.text
	var category: String = WeaponData.WeaponCategory.keys()[data.category].capitalize()
	_weapon_kind.text = category + (" weapon  ·  Equipped" if equipped else " weapon")
	_description.text = (
		data.description.strip_edges()
		if not data.description.strip_edges().is_empty()
		else "No description yet."
	)
	_show_stats(_selection)
	_show_forge(_selection.forge)
	_show_skill(data.secondary_attack)

	_equip_button.text = "Equipped" if equipped else "Equip"
	_equip_button.disabled = equipped or not _can_switch_weapons()
	if equipped:
		_action_hint.text = "This weapon is already equipped."
	elif not _can_switch_weapons():
		_action_hint.text = _switch_block_reason()


func _show_empty_details() -> void:
	_big_icon.texture = null
	_weapon_name.text = "No weapon selected"
	_weapon_name.tooltip_text = ""
	_weapon_kind.text = ""
	_description.text = "Weapons you own appear in the list. Blueprints are crafted at the forge."
	for stat: Stat in _stat_values:
		_stat_values[stat].text = NO_VALUE
	_forge_heading.text = "Forge"
	_show_skill(null)
	_equip_button.text = "Equip"
	_equip_button.disabled = true


func _show_stats(weapon: WeaponInstance) -> void:
	var data := weapon.definition
	var attack := data.normal_attack
	if attack == null:
		for stat: Stat in _stat_values:
			_stat_values[stat].text = NO_VALUE
		return
	var forge := weapon.forge
	var damage := attack.damage_hp
	var speed := BASE_MULTIPLIER
	var crit_rate := data.critical_rate
	var crit_damage := data.critical_damage_multiplier
	var knockback := BASE_MULTIPLIER
	var stagger := data.stagger_damage * attack.stagger_multiplier
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
		reach *= forge.range_multiplier
		if attack.delivery_type == AttackData.DeliveryType.PROJECTILE:
			reach *= forge.projectile_range_multiplier
			knockback *= forge.projectile_knockback_multiplier
	_stat_values[Stat.DAMAGE].text = InventoryMenuFormat.number(damage)
	_stat_values[Stat.ATTACK_SPEED].text = (
		InventoryMenuFormat.signed((speed - BASE_MULTIPLIER) * PERCENT_SCALE) + "%"
	)
	_stat_values[Stat.CRIT_RATE].text = (
		InventoryMenuFormat.number(clampf(crit_rate, 0.0, 1.0) * PERCENT_SCALE) + "%"
	)
	_stat_values[Stat.CRIT_DAMAGE].text = "x" + InventoryMenuFormat.number(crit_damage)
	_stat_values[Stat.CHAOS_GAIN].text = (
		InventoryMenuFormat.number(weapon.get_chaos_gain()) + " / hit"
	)
	_stat_values[Stat.RANGE].text = InventoryMenuFormat.number(reach)
	_stat_values[Stat.KNOCKBACK].text = "x" + InventoryMenuFormat.number(knockback)
	_stat_values[Stat.STAGGER].text = InventoryMenuFormat.number(stagger)


func _show_forge(forge: WeaponForge) -> void:
	if forge == null:
		_forge_heading.text = "Forge"
		_add_forge_row("No forge applied.", 0.0)
		return
	_forge_heading.text = "Forge  ·  " + forge.display_name
	_forge_heading.tooltip_text = forge.description
	var count: int = 0
	for field: String in FORGE_FIELDS:
		var value := float(forge.get(field))
		var additive: bool = field in ADDITIVE_FORGE_FIELDS
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
		if field in COST_FORGE_FIELDS:
			benefit = -benefit
		_add_forge_row("%s %s" % [effect, FORGE_FIELDS[field]], benefit)
		count += 1
	if count == 0:
		_add_forge_row("No stat changes.", 0.0)


func _show_skill(skill: AttackData) -> void:
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
	if skill.ammo_cost > 0 and not skill.ammo_id.is_empty():
		parts.append(
			"%d %s" % [skill.ammo_cost, InventoryMenuFormat.humanize_id(String(skill.ammo_id))]
		)
	_skill_meta.text = "  ·  ".join(parts)
	_skill_description.text = skill.description.strip_edges()


func _on_equip_pressed() -> void:
	if _selection == null or not is_instance_valid(weapons) or _is_equipped(_selection):
		return
	var equipped := weapons.equip(_selection)
	refresh()
	if equipped:
		_action_hint.text = "%s equipped." % _name(_selection)
		_play_equip_feedback()
	else:
		_action_hint.text = (
			_switch_block_reason()
			if not _can_switch_weapons()
			else "This weapon cannot be equipped right now."
		)
		InventoryMenuFx.shake(_equip_button)


func _can_switch_weapons() -> bool:
	if not is_instance_valid(weapons) or weapons.busy:
		return false
	var actor := weapons.actor
	if is_instance_valid(actor) and actor.has_method("can_equip_weapon"):
		return bool(actor.call("can_equip_weapon"))
	return true


func _switch_block_reason() -> String:
	if not is_instance_valid(weapons):
		return "Weapons are unavailable."
	if weapons.busy:
		return "Finish the current attack before switching."
	return "Switch weapons while standing, running or falling."


func _play_equip_feedback() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_current_icon.pivot_offset = _current_icon.size * InventoryMenuFx.CENTER_RATIO
	_current_icon.scale = Vector2.ONE * equip_feedback_scale
	_feedback_tween = create_tween()
	_feedback_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_tween.tween_property(_current_icon, "scale", Vector2.ONE, equip_feedback_seconds)
	InventoryMenuFx.burst(_current_button)
	InventoryMenuFx.burst(_big_icon)


func _build_stat_rows() -> void:
	var line := AtlasTexture.new()
	line.atlas = STAT_SHEET
	line.region = STAT_LINE_REGION
	for stat: Stat in STAT_ICON_REGIONS:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		row.tooltip_text = STAT_TOOLTIPS[stat]
		row.mouse_filter = Control.MOUSE_FILTER_PASS
		var content := HBoxContainer.new()
		content.add_theme_constant_override("separation", stat_icon_gap)
		content.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(content)
		var icon := TextureRect.new()
		var region := AtlasTexture.new()
		region.atlas = STAT_SHEET
		region.region = STAT_ICON_REGIONS[stat]
		icon.texture = region
		icon.custom_minimum_size = Vector2.ONE * stat_icon_size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(icon)
		var name_label := Label.new()
		name_label.text = STAT_NAMES[stat]
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
	_forge_heading.tooltip_text = ""
	for child in _forge_rows.get_children():
		_forge_rows.remove_child(child)
		child.queue_free()


func _is_equipped(weapon: WeaponInstance) -> bool:
	return weapon != null and is_instance_valid(weapons) and weapons.equipped == weapon


func _icon(weapon: WeaponInstance) -> Texture2D:
	return weapon.definition.icon if weapon != null and weapon.definition != null else null


func _name(weapon: WeaponInstance) -> String:
	if weapon == null or weapon.definition == null:
		return "Unknown weapon"
	return weapon.definition.display_name
