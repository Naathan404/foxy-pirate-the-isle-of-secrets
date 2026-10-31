extends CanvasLayer
## Player-owned presentation, driven by the existing confirmed-damage and charge signals.

@export var player: Player
@export var weapons: WeaponController
## Set to zero to disable these flashes; does not affect the existing damage vignette.
@export_range(0.0, 1.0, 0.05) var intensity_scale: float = 1.0
@export_range(0.0, 0.3, 0.01) var maximum_opacity: float = 0.16
@export_range(0.0, 1.0, 0.01) var minimum_interval: float = 0.25
@export_group("Elite Defeat")
@export var elite_color: Color = Color(1.0, 0.78, 0.35)
@export_range(0.0, 0.3, 0.01) var elite_opacity: float = 0.10
@export_range(0.01, 1.0, 0.01) var elite_seconds: float = 0.14
@export_group("Boss Defeat")
@export var boss_color: Color = Color(1.0, 0.92, 0.65)
@export_range(0.0, 1.0, 0.01) var boss_opacity: float = 0.16
@export_range(0.01, 1.0, 0.01) var boss_seconds: float = 0.28
@export_group("Full Bow Release")
@export var bow_color: Color = Color(0.55, 0.85, 1.0)
@export_range(0.0, 1.0, 0.01) var bow_opacity: float = 0.07
@export_range(0.01, 1.0, 0.01) var bow_seconds: float = 0.10

var _fade: Tween
var _last_flash_ms: int = -1000000
var _priority: int = 0

@onready var overlay: ColorRect = $Flash


func _ready() -> void:
	if not is_instance_valid(player) or not is_instance_valid(weapons):
		push_warning("CombatScreenFlash requires player and weapon controller")
		return
	weapons.damage_dealt.connect(_on_damage_dealt)
	weapons.charge_released.connect(_on_charge_released)


func _on_damage_dealt(damage: DamageContext, target: Node, applied_hp: float) -> void:
	if (
		player.dead
		or damage == null
		or damage.source != player
		or applied_hp <= 0.0
		or not damage.target_defeated
		or not is_instance_valid(target)
		or not target is EnemyBase
	):
		return
	# The current turtle scene has no boss group; recognize it for presentation only.
	if target.is_in_group("boss") or target is WarLordTurtle:
		_play_flash(boss_color, boss_opacity, boss_seconds, 3)
	elif target is EliteCrab or target is EliteStarfish or target is EliteBarrel:
		_play_flash(elite_color, elite_opacity, elite_seconds, 2)


func _on_charge_released(context: AttackContext) -> void:
	if (
		player.dead
		or context == null
		or context.actor != player
		or context.weapon == null
		or context.weapon.definition == null
		or context.weapon.definition.weapon_id != &"bow"
		or context.charge_progress < 1.0
		or context.projectile_count <= 1
	):
		return
	_play_flash(bow_color, bow_opacity, bow_seconds, 1)


func _play_flash(color: Color, opacity: float, seconds: float, priority: int) -> void:
	var alpha := clampf(opacity * intensity_scale, 0.0, maximum_opacity)
	if alpha <= 0.0:
		return
	var now := Time.get_ticks_msec()
	# A boss may replace a weaker flash immediately; repeated hits never stack opacity.
	if now - _last_flash_ms < minimum_interval * 1000.0 and priority <= _priority:
		return
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_last_flash_ms = now
	_priority = priority
	overlay.color = Color(color, alpha)
	overlay.show()
	_fade = create_tween().set_ignore_time_scale(true)
	_fade.tween_property(overlay, "color:a", 0.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
	_fade.tween_callback(overlay.hide)
