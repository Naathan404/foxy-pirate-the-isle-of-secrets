extends CharmEffect


func modify_stats(stats: Dictionary[StringName, float]) -> void:
	stats[&"item_drop_multiplier"] = (
		stats.get(&"item_drop_multiplier", 1.0) * definition.get_param_float(&"drop_multiplier")
	)
