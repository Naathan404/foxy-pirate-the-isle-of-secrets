extends DelayedBlastCharm


func on_dash_started() -> void:
	_plant(actor.global_position, CharmVfx.SHADOW, true)
