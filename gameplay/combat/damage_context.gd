class_name DamageContext
extends RefCounted

const Teams := preload("res://gameplay/combat/combat_teams.gd")

# Soure gây daamge
var source: Node
var source_team: int = Teams.NONE

# Thông tin nguồn
var attack_id: int = 0
var amount_hp: int = 1

# đánh dấu tag loại tấn công, đánh thường != mất máu theo thời gian
var tag: StringName = &"normal"
