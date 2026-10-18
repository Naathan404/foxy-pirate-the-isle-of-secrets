class_name DamageContext
extends RefCounted

# Soure gây daamge
var source: Node
var source_team: int = 1

# Thông tin nguồn
var attack_id: int = 0
var amount_hp: int = 1

# đánh dấu tag loại tấn công, đánh thường != mất máu theo thời gian
var tag: StringName = &"normal"
