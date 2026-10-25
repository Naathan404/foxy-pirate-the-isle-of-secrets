class_name CharmEconomyAdapter
extends RefCounted
## Interface tối thiểu cho economy thật; project hiện chưa có wallet/save service.


func can_afford(_amount: int) -> bool:
	return false


func try_spend(_amount: int) -> bool:
	return false


func refund(_amount: int) -> void:
	pass
