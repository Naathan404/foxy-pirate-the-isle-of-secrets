extends CanvasLayer

@export_group("Stat Components")
@export var health: HealthComponent
@export var stamina: StaminaComponent
@export var chaos: ChaosComponent
@export var charm_socket_manager: CharmSocketManager
@export var potion_component: PotionComponent
@export var weapon_controller: WeaponController
@export var ammo: AmmoComponent

var _displayed_ammo_id: StringName = &""

@onready var health_arc: HudStatArc = $Stats/HealthArc
@onready var stamina_arc: HudStatArc = $Stats/StaminaArc
@onready var chaos_arc: HudStatArc = $Stats/ChaosArc
@onready var portrait: HudPortrait = $StatControl/Portrait
@onready var equipment: EquipmentControl = $EquipmentControl
@onready var weapon_icon: TextureRect = $ChaosControl/WeaponFrame/WeaponIcon
@onready var ammo_label: Label = $ChaosControl/AmmoLabel


func _ready() -> void:
	if is_instance_valid(ammo):
		if is_instance_valid(ammo.inventory):
			# Inventory changes cover every ammo ID, including items not in ammo_items yet.
			ammo.inventory.changed.connect(_refresh_ammo)
		else:
			ammo.ammo_changed.connect(_on_ammo_changed)
	_refresh_ammo.call_deferred()
	if is_instance_valid(weapon_controller):
		weapon_controller.weapon_changed.connect(_on_weapon_changed)
		_sync_weapon.call_deferred()
	if is_instance_valid(health):
		health.hp_changed.connect(_on_hp_changed)
		health.damaged.connect(portrait.play_hit_feedback)
		health.died.connect(portrait.show_death)
	if is_instance_valid(stamina):
		stamina.stamina_changed.connect(stamina_arc.set_stat)
	if is_instance_valid(chaos):
		chaos.chaos_changed.connect(chaos_arc.set_stat)
	# Player khởi tạo chỉ số sau khi các node con ready, nên sync ở cuối frame.
	_sync_stats.call_deferred()
	equipment.bind_manager.call_deferred(charm_socket_manager)

	if is_instance_valid(potion_component):
		potion_component.equipped_potion_changed.connect(_on_equipped_potion_changed)
		potion_component.potion_used.connect(equipment.feedback_potion_used)

		if is_instance_valid(potion_component.inventory):
			potion_component.inventory.changed.connect(_refresh_potion_quantity)

		_on_equipped_potion_changed(potion_component.equipped_potion)
	else:
		equipment.set_potion_icon(null)
		equipment.set_potion_quantity(0)


func _sync_weapon() -> void:
	_on_weapon_changed(weapon_controller.equipped)


func _on_weapon_changed(weapon: WeaponInstance) -> void:
	var skill: AttackData
	_displayed_ammo_id = &""
	if weapon != null and weapon.definition != null:
		skill = weapon.definition.secondary_attack
		# Primary ammo takes precedence; secondary supports weapons with skill-only ammo.
		for attack: AttackData in [weapon.definition.normal_attack, skill]:
			if attack != null and not attack.ammo_id.is_empty():
				_displayed_ammo_id = attack.ammo_id
				break
	weapon_icon.texture = skill.skill_icon if skill != null else null
	weapon_icon.visible = weapon_icon.texture != null
	_refresh_ammo()


func _on_ammo_changed(item_id: StringName, _amount: int) -> void:
	if item_id == _displayed_ammo_id:
		_refresh_ammo()


func _refresh_ammo() -> void:
	ammo_label.visible = is_instance_valid(ammo) and not _displayed_ammo_id.is_empty()
	ammo_label.text = str(ammo.get_amount(_displayed_ammo_id)) if ammo_label.visible else ""


func _on_equipped_potion_changed(potion: Potion) -> void:
	equipment.set_potion_icon(potion)
	_refresh_potion_quantity()


func _refresh_potion_quantity() -> void:
	var amount: int = 0
	if is_instance_valid(potion_component):
		amount = potion_component.get_equipped_quantity()

	equipment.set_potion_quantity(amount)


func _sync_stats() -> void:
	if is_instance_valid(health):
		_on_hp_changed(health.get_current_hp(), health.get_max_hp())
	else:
		health_arc.sync_preview()
	if is_instance_valid(stamina):
		stamina_arc.set_stat(stamina.get_current_sp(), stamina.get_max_sp())
	else:
		stamina_arc.sync_preview()
	if is_instance_valid(chaos):
		chaos_arc.set_stat(chaos.current, chaos.maximum)
	else:
		chaos_arc.sync_preview()


func _on_hp_changed(current: float, maximum: float) -> void:
	health_arc.set_stat(current, maximum)
	portrait.set_health(current, maximum)
