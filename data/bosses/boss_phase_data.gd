class_name BossPhaseData
extends Resource

## Phase becomes active at or below this fraction of maximum HP.
@export_range(0.0, 1.0, 0.01) var hp_threshold: float = 1.0
@export_range(0.0, 10.0, 0.1) var skill_interval: float = 1.5
@export var skills: Array[BossSkillData] = []
