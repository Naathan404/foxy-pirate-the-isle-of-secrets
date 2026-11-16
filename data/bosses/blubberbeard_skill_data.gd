class_name BlubberbeardSkillData
extends BossSkillData

enum Kind { POWDER_BARREL, BELLY_CHARGE, SPIKY_INFLATION }

@export var kind: Kind = Kind.POWDER_BARREL
@export_range(0.1, 20.0, 0.1) var radius: float = 2.5
@export_range(0.1, 50.0, 0.1) var speed: float = 10.0
@export_range(0.1, 10.0, 0.1) var duration: float = 1.0
