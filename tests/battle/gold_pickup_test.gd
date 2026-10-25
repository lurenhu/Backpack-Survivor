extends Node

const PICKUP_SCENE: PackedScene = preload("res://scene/battle/pick_up.tscn")

var _observed_balances: Array[int] = []
var _observed_pickups: Array[int] = []


func _ready() -> void:
	BackpackManager.gold_changed.connect(_on_gold_changed)
	CombatManager.gold_collected.connect(_on_combat_gold_collected)
	call_deferred("_run")


func _run() -> void:
	if not _assert(preload("res://tests/battle/battle_test_context.gd").start(self), "battle must start"):
		return
	BackpackManager.set_gold(10)
	GameState.total_gold_collected = 3
	_observed_balances.clear()
	_observed_pickups.clear()

	var pickup := PICKUP_SCENE.instantiate() as Pickup
	add_child(pickup)
	pickup.type = Pickup.PickupType.GOLD
	pickup.value = 7
	pickup._collect()

	if not _assert(BackpackManager.gold == 17, "gold pickup should increase the spendable balance"):
		return
	if not _assert(GameState.total_gold_collected == 10, "gold pickup should increase the cumulative run statistic"):
		return
	if not _assert(_observed_balances == [17], "gold pickup should emit the resulting spendable balance"):
		return
	if not _assert(_observed_pickups == [7], "gold pickup should retain the combat pickup event amount"):
		return
	get_tree().quit(0)


func _on_gold_changed(current_gold: int) -> void:
	_observed_balances.append(current_gold)


func _on_combat_gold_collected(amount: int) -> void:
	_observed_pickups.append(amount)


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("GOLD PICKUP TEST FAILED: %s" % message)
	get_tree().quit(1)
	return false
