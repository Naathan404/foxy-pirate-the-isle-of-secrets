class_name BossData
extends Resource

@export var display_name: String = "Boss"
@export_range(1.0, 100000.0, 1.0) var max_hp: float = 500.0
## Ordered from highest to lowest HP threshold.
@export var phases: Array[BossPhaseData] = []

@export_group("Stagger")
@export_range(1.0, 10000.0, 1.0) var stagger_threshold: float = 340.0
@export_range(0.0, 10.0, 0.05, "suffix:s") var stagger_decay_delay_seconds: float = 1.8
@export_range(0.0, 10000.0, 1.0, "suffix:/s") var stagger_decay_per_second: float = 32.0
@export_range(0.2, 10.0, 0.05, "suffix:s") var stagger_duration_seconds: float = 1.25
## Starts after Staggered state finishes; HP damage still applies during immunity.
@export_range(0.0, 15.0, 0.05, "suffix:s") var stagger_immunity_duration_seconds: float = 4.5
