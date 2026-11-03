class_name EliteBarrel
extends Barrel

@export_group("Elite Barrel Scattershot")
@export_range(1, 12, 1) var scattershot_bullet_count: int = 5
@export_range(0.0, 180.0, 1.0, "suffix:deg") var scattershot_arc_degrees: float = 50.0
