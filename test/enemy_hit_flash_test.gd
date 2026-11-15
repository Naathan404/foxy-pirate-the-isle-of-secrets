extends SceneTree

const ENEMY_SCENES: Array[PackedScene] = [
	preload("res://gameplay/enemies/starfish/starfish.tscn"),
	preload("res://gameplay/enemies/crab/elite_crab.tscn"),
	preload("res://gameplay/enemies/coral_skeleton/coral_skeleton.tscn"),
]
const KICK: Script = preload("res://gameplay/weapons/dagger_sprite_feedback.gd")
var failures := 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func run_tests() -> void:
	for packed in ENEMY_SCENES:
		var enemy := packed.instantiate() as EnemyBase
		root.add_child(enemy)
		await process_frame
		var visual := enemy.visual
		var sprite := visual.sprite
		var original := sprite.material_overlay
		visual.play_hit_feedback()
		var flash := sprite.material_overlay as ShaderMaterial
		check(flash != null and flash.shader == EnemyVisual.HIT_FLASH_SHADER, "enemy uses bright shared flash shader")
		check(flash.get_shader_parameter("strength") == 1.0, "flash begins at full strength")
		visual.play_hit_feedback()
		visual._process(0.016)
		check(flash.get_shader_parameter("sprite_texture") == sprite.texture, "flash tracks the current animation texture")
		var kick: Node = KICK.new()
		sprite.add_child(kick)
		kick.kick(Vector3.RIGHT, 0.01, true)
		check(sprite.material_overlay == flash, "weapon feedback does not replace enemy flash")
		await visual._hit_flash_tween.finished
		check(sprite.material_overlay == original, "original overlay returns after repeated hits: %s (actual %s, expected %s)" % [enemy.name, sprite.material_overlay, original])
		visual.play_hit_feedback()
		visual.play_death_feedback()
		check(sprite.material_overlay == original, "death restores overlay while flash is active")
		enemy.queue_free()
		await process_frame
	print("Enemy hit flash tests: ", "passed" if failures == 0 else "failed")
	quit(0 if failures == 0 else 1)


