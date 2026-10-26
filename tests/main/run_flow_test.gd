extends Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var run := RunState.new()
	run.run_id = 7
	run.battle_id = 11
	run.collected_gold = 25
	for row in [
		[false, false, 0, RunSettlement.Action.RETRY],
		[true, false, 2, RunSettlement.Action.RETURN_TO_MAP],
		[true, true, 2, RunSettlement.Action.NEXT_MAP],
		[true, true, 0, RunSettlement.Action.END_RUN],
	]:
		var result := RunFlow.settle(run, row[0], row[1], row[2])
		if not _check(result.next_action == row[3] and result.run_id == 7 and result.battle_id == 11 and result.collected_gold == 25, "settlement rules and identifiers"):
			return
		var copy := result.snapshot()
		copy.collected_gold = 999
		if not _check(result.collected_gold == 25, "snapshots must be independent"):
			return
	GameState._initialize_run(1)
	var start := MapManager.find_map_node(1, 0, 0)
	MapManager.visit_node(start)
	if not _check(not MapManager.init_map(-1) and MapManager.current_map_node == start and start.visited, "invalid map must preserve progress"):
		return
	var view := preload("res://scene/main/game_over.tscn").instantiate() as GameOver
	add_child(view)
	for action in [RunSettlement.Action.END_RUN, RunSettlement.Action.NEXT_MAP, RunSettlement.Action.RETRY]:
		var result := RunFlow.settle(run, true, true, 2)
		result.next_action = action
		view.show_game_over(result)
		view.update_text()
		view.update_score()
		if not _check(MapManager.current_map_id == 1 and MapManager.current_map_node == start and start.visited, "rendering must not advance or clear the map"):
			return
		if not _check(view.continue_button.visible == (action != RunSettlement.Action.END_RUN), "reused result view must restore button visibility"):
			return
	view.free()
	print("PASS: run settlement rules, independent snapshots, pure result rendering and invalid-map preservation")
	get_tree().quit(0)


func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("RUN FLOW TEST FAILED: " + message)
		get_tree().quit(1)
	return ok
