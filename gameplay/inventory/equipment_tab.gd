extends Control
## A read-only view of combat stats with equipment commands delegated to their owners.

const SLOT := preload("res://gameplay/inventory/equipment_slot.tscn")
const STAT_FONT: FontFile = preload("res://assets/fonts/unifont-17.0.03.otf")
const PAGE_SIZE := 15
const SOCKET_COUNT := 3
const STAT_VALUE_COUNT := 6
const PERCENT_SCALE := 100.0
const BASE_MULTIPLIER := 1.0
const DEFAULT_SP_PER_SECOND := 100.0
const KEYS := ["Q", "SPACE", "E"]

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

@export_group("Forge Attribute Rows")
@export_range(8, 24, 1) var forge_row_font_size := 12
@export var neutral_forge_row_color := Color(0.76, 0.69, 0.60, 0.45)
@export var positive_forge_row_color := Color(0.60, 0.77, 0.55, 0.70)
@export var negative_forge_row_color := Color(0.88, 0.56, 0.50, 0.70)
@export_range(0, 16, 1) var forge_row_corner_radius := 3
@export_range(0.0, 16.0, 1.0) var forge_row_vertical_padding := 2.0

var weapons: WeaponController
var charms: CharmSocketManager
var _show_charms: bool = false
var _page: int = 0
var _entries: Array = []
var _selection: Resource
var _socket: int = 0
var _slots: Array[Button] = []
var _action_hint: String = ""


func _ready() -> void:
	%WeaponsButton.pressed.connect(_set_category.bind(false))
	%CharmsButton.pressed.connect(_set_category.bind(true))
	%Previous.pressed.connect(_turn_page.bind(-1))
	%Next.pressed.connect(_turn_page.bind(1))
	%EquipButton.pressed.connect(_equip_selected)
	%EquippedWeapon.pressed.connect(_select_equipped_weapon)
	for i in SOCKET_COUNT:
		_equipped_slot(i).pressed.connect(_select_socket.bind(i))
	for i in PAGE_SIZE:
		var slot := SLOT.instantiate() as Button
		%ItemGrid.add_child(slot)
		slot.pressed.connect(_select_index.bind(i))
		_slots.append(slot)
	refresh()


func bind_components(controller: WeaponController, manager: CharmSocketManager) -> void:
	weapons = controller
	charms = manager
	if is_instance_valid(weapons):
		weapons.weapon_changed.connect(_on_weapon_changed)
		weapons.collection_changed.connect(refresh)
	if is_instance_valid(charms):
		charms.loadout_changed.connect(_on_loadout_changed)
		charms.socket_unlocked.connect(_on_socket_unlocked)
		charms.safe_location_changed.connect(_on_safe_location_changed)
	refresh()


func refresh() -> void:
	_entries.clear()
	if _show_charms:
		if is_instance_valid(charms) and is_instance_valid(charms.registry):
			for id: StringName in charms.registry.get_registered_ids():
				_entries.append(charms.registry.get_definition(id))
	elif is_instance_valid(weapons):
		_entries.assign(weapons.get_owned_weapons())
	if not _entries.has(_selection):
		_selection = null
		if not _show_charms and is_instance_valid(weapons):
			_selection = weapons.equipped
		if _selection == null and not _entries.is_empty():
			_selection = _entries[0]
	var page_count := maxi(1, ceili(float(_entries.size()) / PAGE_SIZE))
	_page = clampi(_page, 0, page_count - 1)
	%WeaponsButton.set_pressed_no_signal(not _show_charms)
	%CharmsButton.set_pressed_no_signal(_show_charms)
	var active: StyleBox = %WeaponsButton.get_theme_stylebox("hover")
	# Explicit normal styles prevent toggle focus from changing the page geometry.
	for button: Button in [%WeaponsButton, %CharmsButton]:
		button.remove_theme_stylebox_override("normal")
		if button.button_pressed:
			button.add_theme_stylebox_override("normal", active)
	%PageLabel.text = "%d / %d" % [_page + 1, page_count]
	%Previous.disabled = _page == 0
	%Next.disabled = _page == page_count - 1
	for i in PAGE_SIZE:
		var index := _page * PAGE_SIZE + i
		var entry: Resource = _entries[index] if index < _entries.size() else null
		var locked := entry is CharmData and not charms.registry.is_owned(entry.charm_id)
		var badge := "x" if locked else ("E" if _is_equipped(entry) else "")
		_slots[i].present(_icon(entry), badge, entry != null and entry == _selection, locked)
		_slots[i].disabled = entry == null
		_slots[i].tooltip_text = (
			_name(entry) + (" (not owned)" if locked else "") if entry != null else "Empty slot"
		)
	_refresh_equipped()
	_refresh_details()


func _set_category(show_charms: bool) -> void:
	_show_charms = show_charms
	_page = 0
	_selection = null
	refresh()


func _turn_page(direction: int) -> void:
	_page += direction
	refresh()


func _select_index(index: int) -> void:
	index += _page * PAGE_SIZE
	if index < _entries.size():
		_selection = _entries[index]
		refresh()


func _select_equipped_weapon() -> void:
	_show_charms = false
	_selection = weapons.equipped if is_instance_valid(weapons) else null
	_page = (
		maxi(0, floori(float(weapons.get_owned_weapons().find(_selection)) / PAGE_SIZE))
		if is_instance_valid(weapons)
		else 0
	)
	refresh()


func _select_socket(index: int) -> void:
	_socket = index
	_show_charms = true
	if is_instance_valid(charms):
		var id := charms.get_equipped_charm(index)
		if not id.is_empty():
			_selection = charms.registry.get_definition(id)
	refresh()


func _refresh_equipped() -> void:
	var weapon := weapons.equipped if is_instance_valid(weapons) else null
	%EquippedWeapon.present(_icon(weapon), "", weapon != null and not _show_charms)
	%EquippedWeapon.tooltip_text = _name(weapon) if weapon != null else "No weapon equipped"
	for i in SOCKET_COUNT:
		var slot := _equipped_slot(i)
		var unlocked := is_instance_valid(charms) and charms.is_socket_unlocked(i)
		var definition: CharmData
		if is_instance_valid(charms) and is_instance_valid(charms.registry):
			definition = charms.registry.get_definition(charms.get_equipped_charm(i))
		slot.present(_icon(definition), "", _show_charms and _socket == i, not unlocked)
		slot.tooltip_text = KEYS[i] + ": " + (_name(definition) if unlocked else "Locked socket")


func _refresh_details() -> void:
	_action_hint = ""
	%StaggerName.hide()
	%StaggerValue.hide()
	%ChaosGainName.hide()
	%ChaosGainValue.hide()
	%Portrait.texture = _icon(_selection)
	%ItemTitle.text = _name(_selection) if _selection != null else "No equipment"
	%ItemDescription.text = ""
	%ItemKind.text = ""
	%SkillIcon.texture = null
	%SkillTitle.text = "No weapon skill"
	%SkillMeta.text = ""
	%SkillDescription.text = ""
	%EquipButton.disabled = true
	for i in STAT_VALUE_COUNT:
		get_node("%" + "StatValue" + str(i)).text = "--"
	for child in %ForgeRows.get_children():
		%ForgeRows.remove_child(child)
		child.queue_free()
	%StatsHeading.text = "Weapon Stats"
	%ForgeHeading.text = "Forge Attributes"
	%SkillHeading.text = "Weapon Skill"
	if _selection is WeaponInstance:
		_show_weapon(_selection)
	elif _selection is CharmData:
		_show_charm(_selection)
	else:
		%ItemDescription.text = "Equipment you acquire will appear here."
		%EquipButton.text = "Equip"
		_action_hint = "Select a weapon or charm first."
	_refresh_action_art()


func _refresh_action_art() -> void:
	%EquipButton.tooltip_text = (
		%EquipButton.text + ("\n" + _action_hint if not _action_hint.is_empty() else "")
	)


func _set_action_hint(message: String) -> void:
	_action_hint = message
	_refresh_action_art()


func _show_weapon(weapon: WeaponInstance) -> void:
	var data := weapon.definition
	if data == null or data.normal_attack == null:
		return
	%ItemKind.text = "WEAPON  /  EQUIPPED" if _is_equipped(weapon) else "WEAPON"
	%ItemDescription.text = data.description
	%ItemDescription.tooltip_text = data.description
	_set_stat_labels(["Attack", "Crit Damage", "Attack Speed", "Knockback", "Crit Rate", "Range"])
	var forge := weapon.forge
	var speed := forge.attack_speed_multiplier if forge != null else 1.0
	var damage := data.normal_attack.damage_hp
	if forge != null:
		var multiplier := forge.damage_multiplier
		if data.normal_attack.stamina_cost > 0.0 and forge.stamina_cost_multiplier > 0.0:
			multiplier *= forge.stamina_damage_multiplier
		damage = maxf(0.0, damage * multiplier + forge.flat_damage)
	var crit := clampf(
		data.critical_rate + (forge.critical_rate_bonus if forge != null else 0.0), 0.0, 1.0
	)
	var knockback := forge.knockback_multiplier if forge != null else 1.0
	var crit_damage := data.critical_damage_multiplier
	var stagger := data.stagger_damage * data.normal_attack.stagger_multiplier
	if forge != null:
		crit_damage = maxf(
			1.0, crit_damage * forge.critical_damage_multiplier + forge.critical_damage_bonus
		)
		stagger *= forge.stagger_multiplier
	var reach := data.normal_attack.range_units
	if forge != null:
		reach *= forge.range_multiplier
		if data.normal_attack.delivery_type == AttackData.DeliveryType.PROJECTILE:
			reach *= forge.projectile_range_multiplier
			knockback *= forge.projectile_knockback_multiplier
	var values := [
		_number(damage),
		"x" + _number(crit_damage),
		_signed((speed - BASE_MULTIPLIER) * PERCENT_SCALE) + "%",
		"x" + _number(knockback),
		_number(crit * PERCENT_SCALE) + "%",
		_number(reach)
	]
	for i in STAT_VALUE_COUNT:
		get_node("%" + "StatValue" + str(i)).text = values[i]
	%StaggerName.show()
	%StaggerValue.show()
	%StaggerValue.text = _number(stagger)
	%StaggerValue.tooltip_text = "Base stagger with forge applied; combo steps can scale it."
	%ChaosGainName.show()
	%ChaosGainValue.show()
	%ChaosGainValue.text = _number(weapon.get_chaos_gain()) + " CP/hit"
	%ChaosGainValue.tooltip_text = "Weapon Chaos Gain with forge applied, per confirmed enemy hit."
	%StatsHeading.tooltip_text = (
		"Base attack with forge applied. "
		+ "Combo steps and situational Charm effects are calculated on hit."
		+ " Chaos Gain: "
		+ _number(weapon.get_chaos_gain())
		+ " CP per hit."
	)
	if forge == null:
		_add_forge_row("No forge applied")
	else:
		%ForgeHeading.text = "Forge / " + forge.display_name
		%ForgeHeading.tooltip_text = forge.description
		var count := 0
		for field: String in FORGE_FIELDS:
			var value := float(forge.get(field))
			var additive := field in ["flat_damage", "critical_rate_bonus", "critical_damage_bonus"]
			if is_equal_approx(value, 0.0 if additive else 1.0):
				continue
			var effect := (
				_signed(value)
				if field == "flat_damage"
				else (
					_signed((value if additive else value - BASE_MULTIPLIER) * PERCENT_SCALE)
					+ (" pp" if additive else "%")
				)
			)
			var benefit := value - (0.0 if additive else 1.0)
			if field in ["windup_multiplier", "recovery_multiplier", "stamina_cost_multiplier"]:
				benefit = -benefit
			_add_forge_row(effect + " " + FORGE_FIELDS[field], benefit)
			count += 1
		if count == 0:
			_add_forge_row("Unmodified weapon stats")
	var skill := data.secondary_attack
	if skill != null:
		%SkillIcon.texture = skill.skill_icon
		%SkillTitle.text = (
			skill.display_name if not skill.display_name.is_empty() else "Weapon Skill"
		)
		%SkillMeta.text = (
			_number(skill.charge_seconds) + "s charge" if skill.hold_to_charge else ""
		)
		%SkillDescription.text = skill.description
		%SkillDescription.tooltip_text = skill.description
	%EquipButton.text = "Equipped" if _is_equipped(weapon) else "Equip Weapon"
	%EquipButton.disabled = _is_equipped(weapon) or not is_instance_valid(weapons) or weapons.busy


func _show_charm(charm: CharmData) -> void:
	var owned := charms.registry.is_owned(charm.charm_id)
	%ItemKind.text = (
		("ACTIVE CHARM" if charm.is_active() else "PASSIVE CHARM")
		+ (" / EQUIPPED" if _is_equipped(charm) else "")
	)
	%ItemDescription.text = "Choose a socket below to equip this charm."
	%StatsHeading.text = "Charm Details"
	_set_stat_labels(["SP Cost", "Cooldown", "Drop Chance", "Type", "Socket", "Owned"])
	var cost_text := _number(charm.resource_cost)
	if charm.charm_id == &"dead_mans_salute":
		cost_text = _number(
			charm.get_param_float(&"sp_per_second", DEFAULT_SP_PER_SECOND)
		) + "/s"
	var drop_text := (
		"Pending" if charm.drop_chance < 0.0 else _number(charm.drop_chance * 100.0) + "%"
	)
	var values := [
		cost_text,
		_number(charm.cooldown_seconds) + "s",
		drop_text,
		"Active" if charm.is_active() else "Passive",
		KEYS[_socket],
		"Yes" if owned else "No"
	]
	for i in STAT_VALUE_COUNT:
		get_node("%" + "StatValue" + str(i)).text = values[i]
	%ForgeHeading.text = "Availability"
	_add_forge_row("Owned" if owned else "Not acquired yet")
	_add_forge_row("Selected socket: " + KEYS[_socket])
	%SkillHeading.text = "Charm Effect"
	%SkillIcon.texture = charm.sprite
	%SkillTitle.text = charm.display_name
	var prototype_suffix := " | Prototype / balance pending" if charm.is_prototype() else ""
	%SkillMeta.text = (
		_number(charm.cooldown_seconds) + "s cooldown  |  " + cost_text + " SP" + prototype_suffix
		if charm.is_active()
		else drop_text + " drop chance" + prototype_suffix
	)
	%SkillDescription.text = charm.description
	%SkillDescription.tooltip_text = charm.description
	var current := charms.get_equipped_charm(_socket)
	%EquipButton.text = (
		"Unequip " + KEYS[_socket] if current == charm.charm_id else "Equip to " + KEYS[_socket]
	)
	%EquipButton.disabled = (
		not owned
		or not charms.can_change_loadout()
		or not charms.is_socket_unlocked(_socket)
		or (not current.is_empty() and current != charm.charm_id)
	)
	_set_action_hint("Change charms at a safe location.")
	if charms.can_change_loadout():
		_set_action_hint("Select Q, SPACE or E below Currently Equipped.")
		if not charms.is_socket_unlocked(_socket):
			_set_action_hint("This socket is locked.")
		elif not current.is_empty() and current != charm.charm_id:
			_set_action_hint("Select the equipped charm to clear this socket first.")


func _equip_selected() -> void:
	var changed := false
	if _selection is WeaponInstance:
		if not weapons.equip(_selection):
			_set_action_hint("Cannot switch weapons in the current state.")
			return
		changed = true
	elif _selection is CharmData:
		var current := charms.get_equipped_charm(_socket)
		if current == _selection.charm_id:
			changed = charms.unequip_charm(_socket)
		else:
			changed = charms.equip_charm(_selection.charm_id, _socket)
	refresh()
	if changed:
		if _selection is WeaponInstance:
			%EquippedWeapon.play_equip_feedback()
		else:
			_equipped_slot(_socket).play_equip_feedback()


func _add_forge_row(text: String, benefit: float = 0.0) -> void:
	var label := Label.new()
	label.text = "  " + text
	label.tooltip_text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", STAT_FONT)
	label.add_theme_font_size_override("font_size", forge_row_font_size)
	var style := StyleBoxFlat.new()
	style.bg_color = neutral_forge_row_color
	if benefit > 0.0:
		style.bg_color = positive_forge_row_color
	elif benefit < 0.0:
		style.bg_color = negative_forge_row_color
	style.set_corner_radius_all(forge_row_corner_radius)
	style.content_margin_top = forge_row_vertical_padding
	style.content_margin_bottom = forge_row_vertical_padding
	label.add_theme_stylebox_override("normal", style)
	%ForgeRows.add_child(label)


func _set_stat_labels(labels: Array) -> void:
	for i in STAT_VALUE_COUNT:
		get_node(
			"Content/Right/DetailsScroll/Details/Stats/Content/StatsGrid/StatName" + str(i)
		).text = labels[i]


func _is_equipped(entry: Resource) -> bool:
	if entry is WeaponInstance:
		return is_instance_valid(weapons) and weapons.equipped == entry
	if entry is CharmData and is_instance_valid(charms):
		for i in SOCKET_COUNT:
			if charms.get_equipped_charm(i) == entry.charm_id:
				return true
	return false


func _icon(entry: Resource) -> Texture2D:
	if entry is WeaponInstance and entry.definition != null:
		return entry.definition.icon
	if entry is CharmData:
		return entry.sprite
	return null


func _name(entry: Resource) -> String:
	if entry is WeaponInstance and entry.definition != null:
		return entry.definition.display_name
	if entry is CharmData:
		return entry.display_name
	return "Empty"


func _equipped_slot(index: int) -> Button:
	return [%EquippedQ, %EquippedSpace, %EquippedE][index]


func _number(value: float) -> String:
	return ("%.2f" % value).trim_suffix("0").trim_suffix("0").trim_suffix(".")


func _signed(value: float) -> String:
	return ("+" if value >= 0.0 else "") + _number(value)


func _on_weapon_changed(_weapon: WeaponInstance) -> void:
	if not _show_charms:
		_selection = _weapon
	refresh()


func _on_loadout_changed(_socket_id: int, _charm_id: StringName) -> void:
	refresh()


func _on_socket_unlocked(_socket_id: int, _count: int) -> void:
	refresh()


func _on_safe_location_changed(_safe: bool) -> void:
	refresh()
