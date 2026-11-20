extends CanvasLayer

@export var normal_color := Color(0.78, 0.12, 0.10)
@export var final_phase_color := Color(0.72, 0.16, 0.85)
@export var stagger_color := Color(0.95, 0.76, 0.18)
@export var stagger_break_color := Color(1.0, 0.94, 0.55)
@export var stagger_immune_color := Color(0.45, 0.50, 0.56)

var _stagger_fill: StyleBoxFlat

@onready var boss: BossBase = get_parent() as BossBase
@onready var title: Label = $Root/Title
@onready var bar: ProgressBar = $Root/Bar
@onready var stagger_bar: ProgressBar = get_node_or_null("Root/StaggerBar")
@onready var debug_phase2_button: Button = get_node_or_null("Root/DebugPhase2Button")
@onready var debug_stagger_button: Button = get_node_or_null("Root/DebugStaggerButton")
@onready var debug_defeat_button: Button = get_node_or_null("Root/DebugDefeatButton")
@onready var debug_stagger_label: Label = get_node_or_null("Root/DebugStaggerLabel")


func _ready() -> void:
	visible = false
	title.text = boss.boss_data.display_name
	(boss.get_node("HealthComponent") as HealthComponent).hp_changed.connect(_update_hp)
	boss.phase_changed.connect(_update_phase)
	boss.stagger_changed.connect(_update_stagger)
	boss.stagger_broken.connect(_on_stagger_broken)
	boss.fight_started.connect(_on_fight_started)
	boss.fight_finished.connect(func(): visible = false)
	_setup_stagger_bar()
	_setup_debug_button()
	_setup_debug_stagger_button()
	_setup_debug_defeat_button()
	_setup_debug_label()
	_set_color(normal_color)
	set_process(OS.is_debug_build())


func _process(_delta: float) -> void:
	if not visible or not is_instance_valid(boss) or not is_instance_valid(debug_stagger_label):
		return
	if not OS.is_debug_build():
		return
	var summary := boss.get_debug_combat_summary()
	var threshold := boss.get_stagger_threshold()
	var status_part := "Stagger: %d/%d" % [int(round(boss.stagger_amount)), int(round(threshold))]
	if boss.is_staggered():
		status_part = "STUNNED: %.2fs" % boss.get_stagger_active_remaining()
	elif boss.is_stagger_immune():
		status_part = "Immune: %.2fs" % boss.get_stagger_immunity_remaining()
	elif boss.stagger_amount > 0.0 and boss.get_stagger_decay_delay_remaining() > 0.0:
		status_part += " (Decay %.1fs)" % boss.get_stagger_decay_delay_remaining()
	debug_stagger_label.text = (
		"[DEBUG] %s | %s" % [summary, status_part]
		if not summary.is_empty()
		else "[DEBUG] %s" % status_part
	)


func _on_fight_started() -> void:
	visible = true
	if is_instance_valid(boss):
		_update_stagger(
			boss.stagger_amount, boss.get_stagger_threshold(), boss.get_stagger_immunity_remaining()
		)


func _setup_stagger_bar() -> void:
	if not is_instance_valid(stagger_bar):
		return
	_stagger_fill = StyleBoxFlat.new()
	_stagger_fill.bg_color = stagger_color
	_stagger_fill.set_corner_radius_all(3)
	stagger_bar.add_theme_stylebox_override("fill", _stagger_fill)
	stagger_bar.max_value = boss.get_stagger_threshold()
	stagger_bar.value = 0.0


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


func _setup_debug_stagger_button() -> void:
	if not is_instance_valid(debug_stagger_button):
		return
	debug_stagger_button.visible = OS.is_debug_build()
	if (
		debug_stagger_button.visible
		and not debug_stagger_button.pressed.is_connected(_on_debug_stagger_pressed)
	):
		debug_stagger_button.pressed.connect(_on_debug_stagger_pressed)


func _on_debug_stagger_pressed() -> void:
	if is_instance_valid(boss):
		boss.debug_trigger_stagger()


func _setup_debug_defeat_button() -> void:
	if not is_instance_valid(debug_defeat_button):
		return
	debug_defeat_button.visible = OS.is_debug_build()
	if debug_defeat_button.visible:
		debug_defeat_button.pressed.connect(_on_debug_defeat_pressed)


func _on_debug_defeat_pressed() -> void:
	if is_instance_valid(boss):
		boss.debug_defeat()


func _setup_debug_label() -> void:
	if is_instance_valid(debug_stagger_label):
		debug_stagger_label.visible = OS.is_debug_build()


func _refresh_debug_button() -> void:
	if not is_instance_valid(debug_phase2_button) or not is_instance_valid(boss):
		return
	var in_phase2 := boss.phase_index >= 1
	debug_phase2_button.disabled = in_phase2
	debug_phase2_button.text = "Phase 2 Active" if in_phase2 else "Debug: Phase 2"


func _update_hp(current: float, maximum: float) -> void:
	bar.max_value = maximum
	bar.value = current


func _update_stagger(current: float, threshold: float, immunity: float) -> void:
	if not is_instance_valid(stagger_bar):
		return
	stagger_bar.max_value = maxf(1.0, threshold)
	if is_instance_valid(boss) and boss.is_staggered():
		var stun_total := maxf(0.1, boss.boss_data.stagger_duration_seconds)
		stagger_bar.value = (
			threshold * clampf(boss.get_stagger_active_remaining() / stun_total, 0.0, 1.0)
		)
		_set_stagger_fill_color(stagger_break_color)
	elif immunity > 0.0 and is_instance_valid(boss) and boss.boss_data != null:
		var imm_total := maxf(0.1, boss.boss_data.stagger_immunity_duration_seconds)
		stagger_bar.value = threshold * clampf(immunity / imm_total, 0.0, 1.0)
		_set_stagger_fill_color(stagger_immune_color)
	else:
		stagger_bar.value = clampf(current, 0.0, threshold)
		_set_stagger_fill_color(stagger_color)


func _on_stagger_broken(_duration_seconds: float) -> void:
	if is_instance_valid(boss):
		_update_stagger(
			boss.stagger_amount, boss.get_stagger_threshold(), boss.get_stagger_immunity_remaining()
		)


func _update_phase(index: int) -> void:
	if index == boss.boss_data.phases.size() - 1:
		_set_color(final_phase_color)
	_refresh_debug_button()


func _set_color(color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)


func _set_stagger_fill_color(color: Color) -> void:
	if _stagger_fill != null:
		_stagger_fill.bg_color = color
