extends CanvasLayer

@export var normal_color := Color(0.78, 0.12, 0.10)
@export var final_phase_color := Color(0.72, 0.16, 0.85)

@onready var boss: BossBase = get_parent() as BossBase
@onready var title: Label = $Root/Title
@onready var bar: ProgressBar = $Root/Bar


func _ready() -> void:
	visible = false
	title.text = boss.boss_data.display_name
	(boss.get_node("HealthComponent") as HealthComponent).hp_changed.connect(_update_hp)
	boss.phase_changed.connect(_update_phase)
	boss.fight_started.connect(func(): visible = true)
	boss.fight_finished.connect(func(): visible = false)
	_set_color(normal_color)


func _update_hp(current: float, maximum: float) -> void:
	bar.max_value = maximum
	bar.value = current


func _update_phase(index: int) -> void:
	if index == boss.boss_data.phases.size() - 1:
		_set_color(final_phase_color)


func _set_color(color: Color) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
