class_name BossData
extends Resource

@export var display_name: String = "Boss"
@export_range(1.0, 100000.0, 1.0) var max_hp: float = 500.0
## Ordered from highest to lowest HP threshold.
@export var phases: Array[BossPhaseData] = []
