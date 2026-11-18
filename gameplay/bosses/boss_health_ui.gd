extends CanvasLayer

@export var normal_color := Color(0.78, 0.12, 0.10)
@export var final_phase_color := Color(0.72, 0.16, 0.85)

@onready var boss: BossBase = get_parent() as BossBase
@onready var title: Label = $Root/Title
@onready var bar: ProgressBar = $Root/Bar
@onready var debug_phase2_button: Button = get_node_or_null("Root/DebugPhase2Button")
@onready var debug_defeat_button: Button = get_node_or_null("Root/DebugDefeatButton")


func _ready() -> void:
	visible = false
	title.text = boss.boss_data.display_name
	(boss.get_node("HealthComponent") as HealthComponent).hp_changed.connect(_update_hp)
	boss.phase_changed.connect(_update_phase)
	boss.fight_started.connect(func(): visible = true)
	boss.fight_finished.connect(func(): visible = false)
	_setup_debug_button()
	_setup_debug_defeat_button()
	_set_color(normal_color)


func _setup_debug_button() -> void:
	if not is_instance_valid(debug_phase2_button):
		return
	var can_show := (
		OS.is_debug_build() and boss.boss_data != null and boss.boss_data.phases.size() > 1
	)
	debug_phase2_button.visible = can_show
	if not can_show:
		return
	_refresh_debug_button()
	if not debug_phase2_button.pressed.is_connected(_on_debug_phase2_pressed):
		debug_phase2_button.pressed.connect(_on_debug_phase2_pressed)


func _on_debug_phase2_pressed() -> void:
	if is_instance_valid(boss):
		boss.debug_trigger_phase_two()
	_refresh_debug_button()


func _setup_debug_defeat_button() -> void:
	if not is_instance_valid(debug_defeat_button):
		return
	debug_defeat_button.visible = OS.is_debug_build()
	if debug_defeat_button.visible:
		debug_defeat_button.pressed.connect(_on_debug_defeat_pressed)


func _on_debug_defeat_pressed() -> void:
	if is_instance_valid(boss):
		boss.debug_defeat()


func _refresh_debug_button() -> void:
	if not is_instance_valid(debug_phase2_button) or not is_instance_valid(boss):
		return
	var in_phase2 := boss.phase_index >= 1
	debug_phase2_button.disabled = in_phase2
	debug_phase2_button.text = "Phase 2 Active" if in_phase2 else "Debug: Phase 2"


func _update_hp(current: float, maximum: float) -> void:
	bar.max_value = maximum
	bar.value = current


func _update_phase(index: int) -> void:
	if index == boss.boss_data.phases.size() - 1:
		_set_color(final_phase_color)
	_refresh_debug_button()


func _set_color(color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
