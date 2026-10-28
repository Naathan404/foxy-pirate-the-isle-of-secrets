extends CanvasLayer

@export_group("Stat Components")
@export var health: HealthComponent
@export var stamina: StaminaComponent
@export var chaos: ChaosComponent
@export var charm_socket_manager: CharmSocketManager
@export var potion_component: PotionComponent

@onready var health_arc: HudStatArc = $Stats/HealthArc
@onready var stamina_arc: HudStatArc = $Stats/StaminaArc
@onready var chaos_arc: HudStatArc = $Stats/ChaosArc
@onready var portrait: HudPortrait = $StatControl/Portrait
@onready var equipment: EquipmentControl = $EquipmentControl


func _ready() -> void:
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


func _on_hp_changed(current: int, maximum: int) -> void:
	health_arc.set_stat(current, maximum)
	portrait.set_health(current, maximum)
 