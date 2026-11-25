class_name InventoryMenuFx
extends RefCounted
## Tween and particle helpers shared by the inventory menu pages.

const SPARKLE_SCENE: PackedScene = preload("res://gameplay/inventory/menu/sparkle_burst.tscn")
## The menu's overlay Control joins this group so bursts draw above every page.
const FX_GROUP := &"inventory_menu_fx"
const POP_TWEEN_META := &"_inventory_fx_pop"
const SHAKE_TWEEN_META := &"_inventory_fx_shake"
const SHAKE_BASE_META := &"_inventory_fx_shake_base"
const POP_SECONDS := 0.3
const POP_FADE_RATIO := 0.6
const SHAKE_SECONDS := 0.3
const SHAKE_STEPS := 6
const SHAKE_PIXELS := 7.0
const STAGGER_STEP_SECONDS := 0.016
const STAGGER_MAX_STEPS := 24
const STAGGER_FROM_SCALE := 0.8
## Start scale of the big featured icon when a new entry is selected.
const ICON_POP_FROM_SCALE := 0.6
## Start scale of small equipped/assigned icons celebrating a change.
const BADGE_POP_FROM_SCALE := 0.4
const DEFAULT_POP_FROM_SCALE := 0.7
const CENTER_RATIO := 0.5


## Springs a control in from a smaller scale and transparent alpha.
static func pop(
	target: Control, from_scale: float = DEFAULT_POP_FROM_SCALE, delay_seconds: float = 0.0
) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return
	_kill_meta_tween(target, POP_TWEEN_META)
	target.pivot_offset = target.size * CENTER_RATIO
	target.scale = Vector2.ONE * from_scale
	target.modulate.a = 0.0
	var tween := target.create_tween().set_parallel()
	target.set_meta(POP_TWEEN_META, tween)
	var grow := tween.tween_property(target, "scale", Vector2.ONE, POP_SECONDS)
	grow.set_delay(delay_seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var fade := tween.tween_property(target, "modulate:a", 1.0, POP_SECONDS * POP_FADE_RATIO)
	fade.set_delay(delay_seconds)


## Pops visible controls one after another, e.g. grid cells when a page appears.
static func stagger_in(targets: Array) -> void:
	var step: int = 0
	for target: Control in targets:
		if not is_instance_valid(target) or not target.visible:
			continue
		pop(target, STAGGER_FROM_SCALE, mini(step, STAGGER_MAX_STEPS) * STAGGER_STEP_SECONDS)
		step += 1


## Short horizontal shake used when an action is refused.
static func shake(target: Control) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return
	var base: Vector2 = target.get_meta(SHAKE_BASE_META, target.position)
	_kill_meta_tween(target, SHAKE_TWEEN_META)
	target.set_meta(SHAKE_BASE_META, base)
	target.position = base
	var tween := target.create_tween()
	target.set_meta(SHAKE_TWEEN_META, tween)
	var step_seconds := SHAKE_SECONDS / (SHAKE_STEPS + 1)
	for step in range(SHAKE_STEPS):
		var falloff := 1.0 - float(step) / SHAKE_STEPS
		var direction := 1.0 if step % 2 == 0 else -1.0
		tween.tween_property(
			target, "position:x", base.x + SHAKE_PIXELS * falloff * direction, step_seconds
		)
	tween.tween_property(target, "position:x", base.x, step_seconds)
	tween.tween_callback(target.remove_meta.bind(SHAKE_BASE_META))


## One-shot sparkle burst centered on a control, drawn on the visible menu overlay. Several menus
## (Inventory, shops) own an overlay in FX_GROUP; only the one on screen can host the burst.
static func burst(anchor: Control) -> void:
	if not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return
	var host: Control
	for node: Node in anchor.get_tree().get_nodes_in_group(FX_GROUP):
		var candidate := node as Control
		if candidate != null and candidate.is_visible_in_tree():
			host = candidate
			break
	if host == null:
		return
	var particles := SPARKLE_SCENE.instantiate() as CPUParticles2D
	# The scene uses local_coords and a host-local position: with global coordinates the Web
	# export emits from the canvas origin (top-left) instead of the anchor.
	particles.position = (
		host.get_global_transform().affine_inverse() * anchor.get_global_rect().get_center()
	)
	host.add_child(particles)
	particles.finished.connect(particles.queue_free)
	particles.emitting = true


static func _kill_meta_tween(target: Control, key: StringName) -> void:
	if not target.has_meta(key):
		return
	var previous := target.get_meta(key) as Tween
	if previous != null and previous.is_valid():
		previous.kill()
