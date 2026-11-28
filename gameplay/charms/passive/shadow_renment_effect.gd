extends DelayedBlastCharm

const WORD := "SHADOW"


func on_dash_started() -> void:
	_plant(actor.global_position, CharmBlastVfx.Kind.SHADOW, CharmVfx.SHADOW, WORD)
