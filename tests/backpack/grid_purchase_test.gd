extends Node

var _observed_gold: Array[int] = []


func _ready() -> void:
	BackpackManager.gold_changed.connect(_on_gold_changed)
	call_deferred("_run")


func _run() -> void:
	if not _test_only_orthogonal_locked_neighbors_are_purchasable():
		return
	if not _test_insufficient_gold_does_not_unlock_grid():
		return
	if not _test_purchase_unlocks_grid_and_doubles_cost():
		return
	get_tree().quit(0)


func _test_only_orthogonal_locked_neighbors_are_purchasable() -> bool:
	BackpackManager.backpack_grid = [
		[-1, -1, -1],
		[-1, 0, -1],
		[-1, -1, -1],
	]
	var cells: Array[Vector2i] = BackpackManager.get_purchasable_grid_cells()
	var expected: Array[Vector2i] = [
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(2, 1),
		Vector2i(1, 2),
	]
	if not _assert(cells.size() == 4, "only four orthogonal neighbors should be purchasable"):
		return false
	for cell in expected:
		if not _assert(cell in cells, "missing purchasable neighbor %s" % cell):
			return false
	return _assert(Vector2i(0, 0) not in cells, "diagonal cells should not be purchasable")


func _test_insufficient_gold_does_not_unlock_grid() -> bool:
	BackpackManager.backpack_grid = [[0, -1]]
	BackpackManager.grid_cost = 10
	BackpackManager.set_grid_purchase_mode(true)
	BackpackManager.set_gold(9)
	_observed_gold.clear()
	var purchased: bool = BackpackManager.purchase_grid(Vector2i(1, 0))
	if not _assert(not purchased, "purchase should fail when gold is insufficient"):
		return false
	if not _assert(BackpackManager.backpack_grid[0][1] == -1, "failed purchase should keep grid locked"):
		return false
	if not _assert(BackpackManager.gold == 9, "failed purchase should not spend gold"):
		return false
	if not _assert(BackpackManager.grid_cost == 10, "failed purchase should not change cost"):
		return false
	return _assert(_observed_gold.is_empty(), "failed purchase should not emit gold_changed")


func _test_purchase_unlocks_grid_and_doubles_cost() -> bool:
	BackpackManager.backpack_grid = [[0, -1, -1]]
	BackpackManager.grid_cost = 10
	BackpackManager.set_grid_purchase_mode(true)
	BackpackManager.set_gold(25)
	var purchased: bool = BackpackManager.purchase_grid(Vector2i(1, 0))
	if not _assert(purchased, "adjacent grid should be purchased"):
		return false
	if not _assert(BackpackManager.backpack_grid[0][1] == 0, "purchased grid should become unlocked"):
		return false
	if not _assert(BackpackManager.gold == 15, "successful purchase should spend the current cost"):
		return false
	if not _assert(BackpackManager.grid_cost == 20, "successful purchase should double the next cost"):
		return false
	return _assert(
		Vector2i(2, 0) in BackpackManager.get_purchasable_grid_cells(),
		"unlocking a grid should expose its next locked neighbor"
	)


func _on_gold_changed(current_gold: int) -> void:
	_observed_gold.append(current_gold)


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("GRID PURCHASE TEST FAILED: %s" % message)
	get_tree().quit(1)
	return false
