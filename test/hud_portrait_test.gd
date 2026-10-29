extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://gameplay/player/hud/player_hud.tscn") as PackedScene
	var hud := scene.instantiate() as CanvasLayer
	root.add_child(hud)
	var portrait := hud.get_node("StatControl/Portrait") as HudPortrait
	var animation := portrait.get_node("AnimationPlayer") as AnimationPlayer
	portrait.set_health(31, 100)
	_check(portrait.texture == portrait.healthy_texture, "Above 30 percent uses healthy portrait")
	_check(not animation.is_playing(), "Healthy portrait does not animate")
	portrait.set_health(30, 100)
	var atlas := portrait.low_health_texture as AtlasTexture
	_check(portrait.texture == atlas and animation.is_playing(), "Exactly 30 percent starts loop")
	_check(atlas.atlas.resource_path.ends_with("30%_status-Sheet.png"), "Uses requested sheet")
	_check(atlas.region == Rect2(0, 0, 48, 48), "Starts at first 48px frame")
	animation.advance(0.13)
	_check(atlas.region == Rect2(48, 0, 48, 48), "Animation selects second sheet frame")
	var progress := animation.current_animation_position
	portrait.set_health(29, 100)
	_check(
		is_equal_approx(animation.current_animation_position, progress), "HP changes keep progress"
	)
	animation.advance(0.125)
	_check(atlas.region == Rect2(96, 0, 48, 48), "Animation selects third frame")
	animation.advance(0.125)
	_check(atlas.region == Rect2(144, 0, 48, 48), "Animation selects fourth frame")
	animation.advance(0.125)
	_check(atlas.region == Rect2(0, 0, 48, 48), "Animation wraps to first frame")
	var other_hud := scene.instantiate() as CanvasLayer
	root.add_child(other_hud)
	var other := other_hud.get_node("StatControl/Portrait") as HudPortrait
	other.set_health(30, 100)
	animation.advance(0.125)
	_check(
		atlas != other.low_health_texture, "HUD instances have independent AtlasTexture resources"
	)
	_check(
		(other.low_health_texture as AtlasTexture).region.position.x == 0, "No shared frame changes"
	)
	portrait.play_hit_feedback(1)
	_check(portrait.texture == portrait.hit_texture, "Hit portrait overrides low HP animation")
	_check(not animation.is_playing(), "Hit pauses low HP loop")
	portrait._process(portrait.hit_duration + 0.01)
	_check(portrait.texture == atlas and animation.is_playing(), "Low HP resumes after hit")
	portrait.play_hit_feedback(1)
	portrait.set_health(50, 100)
	_check(portrait.texture == portrait.hit_texture, "Healing during hit keeps hit priority")
	portrait._process(portrait.hit_duration + 0.01)
	_check(
		portrait.texture == portrait.healthy_texture, "Healing above threshold restores portrait"
	)
	_check(not animation.is_playing(), "Healing stops low HP loop")
	portrait.set_health(30, 100)
	portrait.play_hit_feedback(1)
	portrait.set_health(0, 100)
	_check(portrait._hit_remaining == 0.0, "Death cancels hit shake immediately")
	_check(not animation.is_playing(), "Death stops low HP animation")
	_check(portrait.texture != atlas, "Death overrides animated atlas")
	portrait.play_hit_feedback(1)
	_check(portrait._hit_remaining == 0.0, "Hit cannot override death")
	portrait.set_health(30, 100)
	_check(atlas.region.position.x == 0, "Re-entering low HP restarts from first frame")
	paused = true
	_check(not animation.can_process(), "Portrait animation respects gameplay pause")
	progress = animation.current_animation_position
	await process_frame
	await process_frame
	_check(
		is_equal_approx(animation.current_animation_position, progress),
		"Paused loop does not advance"
	)
	paused = false
	hud.free()
	other_hud.free()
	if _failures == 0:
		print("Portrait sheet frames, 30 percent threshold, hit/death priority and pause passed")
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
