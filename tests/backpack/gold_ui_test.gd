extends Node

const PACKAGE_SCENE := preload("res://scene/shop/package.tscn")
const BATTLE_UI_SCENE := preload("res://scene/battle/battle_ui.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	BackpackManager._inventory.grids[BackpackManager.GridType.PACKAGE] = []
	BackpackManager._inventory.grids[BackpackManager.GridType.STAGE] = []
	BackpackManager.set_gold(25)
	var package := PACKAGE_SCENE.instantiate() as Package
	add_child(package)
	if not _assert(package.get_node("Coin/Label").text == "25", "package should render the current gold when it becomes ready"):
		return
	BackpackManager.add_gold(5)
	if not _assert(package.get_node("Coin/Label").text == "30", "package should update when gold_changed is emitted"):
		return

	BackpackManager.set_gold(41)
	var battle_ui := BATTLE_UI_SCENE.instantiate() as BattleUI
	add_child(battle_ui)
	if not _assert(battle_ui.get_node("Gold/Value").text == "41", "battle UI should render the current gold when it becomes ready"):
		return
	BackpackManager.add_gold(2)
	if not _assert(battle_ui.get_node("Gold/Value").text == "43", "battle UI should update when gold_changed is emitted"):
		return
	battle_ui.queue_free()
	package.queue_free()
	get_tree().quit(0)


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("GOLD UI TEST FAILED: %s" % message)
	get_tree().quit(1)
	return false
