extends Node

var _observed_gold: Array[int] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	BackpackManager.gold_changed.connect(_on_gold_changed)
	BackpackManager.set_gold(0)
	_observed_gold.clear()

	BackpackManager.set_gold(10)
	if not _assert(BackpackManager.gold == 10, "set_gold should update the balance"):
		return
	if not _assert(BackpackManager.add_gold(5), "positive additions should succeed"):
		return
	if not _assert(BackpackManager.add_gold(0) == false, "zero additions should fail"):
		return
	if not _assert(BackpackManager.add_gold(-1) == false, "negative additions should fail"):
		return
	if not _assert(BackpackManager.spend_gold(15), "affordable spends should succeed"):
		return
	if not _assert(BackpackManager.spend_gold(1) == false, "insufficient spends should fail"):
		return
	if not _assert(BackpackManager.spend_gold(0) == false, "zero spends should fail"):
		return
	if not _assert(BackpackManager.spend_gold(-1) == false, "negative spends should fail"):
		return
	if not _assert(BackpackManager.gold == 0, "failed spends should not mutate the balance"):
		return
	if not _assert(_observed_gold == [10, 15, 0], "only successful changes should emit the observed balances"):
		return
	_observed_gold.clear()
	BackpackManager.set_gold(3)
	_observed_gold.clear()
	BackpackManager.set_gold(-1)
	if not _assert(BackpackManager.gold == 0, "negative set_gold should clamp the balance to zero"):
		return
	if not _assert(_observed_gold == [0], "clamping a changed balance should emit zero"):
		return
	get_tree().quit(0)


func _on_gold_changed(current_gold: int) -> void:
	_observed_gold.append(current_gold)


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("GOLD MANAGER TEST FAILED: %s" % message)
	get_tree().quit(1)
	return false
