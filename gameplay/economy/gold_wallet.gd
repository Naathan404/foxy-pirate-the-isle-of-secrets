class_name GoldWallet
extends RefCounted
## One runtime balance, owned by GameManager so changing scenes does not reset Gold.

signal balance_changed(balance: int, change: int)

const MAX_GOLD: int = 9223372036854775807

var _balance: int = 0


func get_balance() -> int:
	return _balance


func add_gold(amount: int) -> bool:
	if amount <= 0 or amount > MAX_GOLD - _balance:
		return false
	_balance += amount
	balance_changed.emit(_balance, amount)
	return true


func can_afford(amount: int) -> bool:
	return amount >= 0 and _balance >= amount


func try_spend(amount: int) -> bool:
	if not can_afford(amount):
		return false
	if amount > 0:
		_balance -= amount
		balance_changed.emit(_balance, -amount)
	return true
