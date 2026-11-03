class_name CharmEconomyAdapter
extends RefCounted
## Purchase interface; a concrete adapter must delegate to the shared GoldWallet.


func can_afford(_amount: int) -> bool:
	return false


func try_spend(_amount: int) -> bool:
	return false


func refund(_amount: int) -> void:
	pass
