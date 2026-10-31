extends Control
## A read-only view of combat stats with equipment commands delegated to their owners.

const SLOT := preload("res://gameplay/inventory/equipment_slot.tscn")
const EQUIP_TEXTURE: Texture2D = preload("res://assets/ui/player_hud/inventory/equip_button.png")
const EQUIP_PRESSED_TEXTURE: Texture2D = preload(
	"res://assets/ui/player_hud/inventory/equip_button_press.png"
)
const UNEQUIP_TEXTURE: Texture2D = preload(
	"res://assets/ui/player_hud/inventory/unequip_button.png"
)
const UNEQUIP_PRESSED_TEXTURE: Texture2D = preload(
	"res://assets/ui/player_hud/inventory/unequip_button_press.png"
)
const PAGE_SIZE := 20
const KEYS := ["Q", "SPACE", "E"]
const FORGE_FIELDS := {
	"damage_multiplier": "Damage",
	"flat_damage": "Flat Damage",
	"attack_speed_multiplier": "Attack Speed",
	"critical_rate_bonus": "Crit Rate",
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
	resized.connect(_layout_content)
	_layout_content.call_deferred()
	%WeaponsButton.pressed.connect(_set_category.bind(false))
	%CharmsButton.pressed.connect(_set_category.bind(true))
	%Previous.pressed.connect(_turn_page.bind(-1))
	%Next.pressed.connect(_turn_page.bind(1))
	%EquipButton.pressed.connect(_equip_selected)
	%EquipButton.button_down.connect(_refresh_action_art.bind(true))
	%EquipButton.button_up.connect(_refresh_action_art.bind(false))
	%EquippedWeapon.pressed.connect(_select_equipped_weapon)
	for i in 3:
		_equipped_slot(i).pressed.connect(_select_socket.bind(i))
	for i in PAGE_SIZE:
		var slot := SLOT.instantiate() as Button
		%ItemGrid.add_child(slot)
		slot.pressed.connect(_select_index.bind(i))
		_slots.append(slot)


## Only the equipment contents adapt; the inventory book keeps its original transforms.
func _layout_content() -> void:
	var content := $Content as HBoxContainer
	var left := $Content/Left as VBoxContainer
	var right := $Content/Right as VBoxContainer
	left.custom_minimum_size.x = 0.0
	right.custom_minimum_size.x = 0.0
	var page_width := maxf(
		380.0, maxf(left.get_combined_minimum_size().x, right.get_combined_minimum_size().x)
	)
	left.custom_minimum_size.x = page_width
	right.custom_minimum_size.x = page_width
	content.size = content.get_combined_minimum_size().max(Vector2(808.0, 480.0))
	# Original artwork extends outside its panel; keep all contents inside the paper borders.
	var available := size - Vector2(16.0, 52.0)
	var factor := minf(available.x / content.size.x, available.y / content.size.y)
	content.scale = Vector2.ONE * factor
	content.position = Vector2(8.0, 8.0) + (available - content.size * factor) * 0.5


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
	_layout_content.call_deferred()


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
		maxi(0, weapons.get_owned_weapons().find(_selection) / PAGE_SIZE)
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
	%EquippedWeapon.present(_icon(weapon), "", not _show_charms)
	%EquippedWeapon.tooltip_text = _name(weapon)
	for i in 3:
		var slot := _equipped_slot(i)
		var unlocked := is_instance_valid(charms) and charms.is_socket_unlocked(i)
		var definition: CharmData
		if is_instance_valid(charms) and is_instance_valid(charms.registry):
			definition = charms.registry.get_definition(charms.get_equipped_charm(i))
		slot.present(_icon(definition), "", _show_charms and _socket == i, not unlocked)
		slot.tooltip_text = KEYS[i] + ": " + (_name(definition) if unlocked else "Locked socket")


func _refresh_details() -> void:
	_action_hint = ""
	%Portrait.texture = _icon(_selection)
	%ItemTitle.text = _name(_selection) if _selection != null else "No equipment"
	%ItemDescription.text = ""
	%ItemKind.text = ""
	%SkillIcon.texture = null
	%SkillTitle.text = "No weapon skill"
	%SkillMeta.text = ""
	%SkillDescription.text = ""
	%EquipButton.disabled = true
	for i in 6:
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
		%EquipButton.text = "No equipment selected"
	_refresh_action_art()


## Inventory action artwork includes its own lettering; keep Button.text for semantics/tooltips.
func _refresh_action_art(held: bool = false) -> void:
	var unequip: bool = %EquipButton.text.begins_with("Unequip")
	var artwork: TextureRect = %EquipButton.get_node("Artwork")
	if unequip:
		artwork.texture = UNEQUIP_PRESSED_TEXTURE if held else UNEQUIP_TEXTURE
	else:
		artwork.texture = EQUIP_PRESSED_TEXTURE if held else EQUIP_TEXTURE
	artwork.modulate = Color(0.6, 0.6, 0.6, 0.75) if %EquipButton.disabled else Color.WHITE
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
	var reach := data.normal_attack.range_units
	if forge != null:
		reach *= forge.range_multiplier
		if data.normal_attack.delivery_type == AttackData.DeliveryType.PROJECTILE:
			reach *= forge.projectile_range_multiplier
			knockback *= forge.projectile_knockback_multiplier
	var values := [
		_number(damage),
		"x" + _number(data.critical_damage_multiplier),
		_signed((speed - 1.0) * 100.0) + "%",
		"x" + _number(knockback),
		_number(crit * 100.0) + "%",
		_number(reach)
	]
	for i in 6:
		get_node("%" + "StatValue" + str(i)).text = values[i]
	%StatsHeading.tooltip_text = (
		"Base attack with forge applied. "
		+ "Combo steps and situational Charm effects are calculated on hit."
	)
	if forge == null:
		_add_forge_row("No forge applied", 0)
	else:
		%ForgeHeading.text = "Forge / " + forge.display_name
		%ForgeHeading.tooltip_text = forge.description
		var count := 0
		for field: String in FORGE_FIELDS:
			var value := float(forge.get(field))
			var additive := field in ["flat_damage", "critical_rate_bonus"]
			if is_equal_approx(value, 0.0 if additive else 1.0):
				continue
			var effect := (
				_signed(value)
				if field == "flat_damage"
				else (
					_signed((value if additive else value - 1.0) * 100.0)
					+ (" pp" if field == "critical_rate_bonus" else "%")
				)
			)
			_add_forge_row(effect + " " + FORGE_FIELDS[field], count)
			count += 1
		if count == 0:
			_add_forge_row("Unmodified weapon stats", 0)
	var skill := data.secondary_attack
	if skill != null:
		%SkillIcon.texture = skill.skill_icon
		%SkillTitle.text = (
			skill.display_name if not skill.display_name.is_empty() else "Weapon Skill"
		)
		%SkillMeta.text = (
			"RMB  |  "
			+ (
				_number(skill.charge_seconds) + "s charge"
				if skill.hold_to_charge
				else _number(skill.cooldown_seconds / speed) + "s cooldown"
			)
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
	_set_stat_labels(["CP Cost", "Cooldown", "Proc Rate", "Type", "Socket", "Owned"])
	var values := [
		_number(charm.resource_cost),
		_number(charm.cooldown_seconds) + "s",
		_number(charm.proc_chance * 100.0) + "%",
		"Active" if charm.is_active() else "Passive",
		KEYS[_socket],
		"Yes" if owned else "No"
	]
	for i in 6:
		get_node("%" + "StatValue" + str(i)).text = values[i]
	%ForgeHeading.text = "Availability"
	_add_forge_row("Owned" if owned else "Not acquired yet", 0)
	_add_forge_row("Selected socket: " + KEYS[_socket], 1)
	%SkillHeading.text = "Charm Effect"
	%SkillIcon.texture = charm.sprite
	%SkillTitle.text = charm.display_name
	%SkillMeta.text = (
		_number(charm.cooldown_seconds) + "s cooldown  |  " + _number(charm.resource_cost) + " CP"
		if charm.is_active()
		else _number(charm.proc_chance * 100.0) + "% proc chance"
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


func _add_forge_row(text: String, index: int) -> void:
	var label := Label.new()
	label.text = "  " + text
	label.tooltip_text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	var style := StyleBoxFlat.new()
	style.bg_color = (
		Color(0.75, 0.64, 0.77, 0.65) if index % 2 == 0 else Color(0.62, 0.74, 0.83, 0.65)
	)
	style.set_corner_radius_all(3)
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	label.add_theme_stylebox_override("normal", style)
	%ForgeRows.add_child(label)


func _set_stat_labels(labels: Array) -> void:
	for i in 6:
		get_node("Content/Right/Stats/Content/StatsGrid/StatName" + str(i)).text = labels[i]


func _is_equipped(entry: Resource) -> bool:
	if entry is WeaponInstance:
		return is_instance_valid(weapons) and weapons.equipped == entry
	if entry is CharmData and is_instance_valid(charms):
		for i in 3:
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
