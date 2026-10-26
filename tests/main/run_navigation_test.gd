extends Node
## 保留测试节点在根节点下，实际游戏场景由正式路由切换。

func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var bootstrap := Node.new()
	bootstrap.scene_file_path = "res://scene/main/main_menu.tscn"
	get_tree().root.add_child(bootstrap)
	get_tree().current_scene = bootstrap
	GameState.fade_out_options = SceneManager.create_options(0.01, "fade")
	GameState.fade_in_options = SceneManager.create_options(0.01, "fade")
	GameState.general_options = SceneManager.create_general_options(Color.BLACK, 0, false, false)
	if not _check(not GameState.start_run(-1) and GameState.run_id == 0, "invalid character must preserve menu state"):
		return
	if not _check(GameState.show_character_select(), "menu must open character selection") or not await _wait_phase(RunState.Phase.CHARACTER_SELECT):
		return
	if not _check(GameState.start_run(1) and not GameState.start_run(2), "start must reject a second click") or not await _wait_phase(RunState.Phase.MAP):
		return
	var initial_run_id := GameState.run_id
	if not _check(not GameState.enter_map_node(1, 3, 0) and not GameState.enter_map_node(99, 0, 0), "unreachable and foreign nodes must be rejected"):
		return
	var shop_config: ShopConfigData = GameConfig.shops[1]
	GameConfig.shops.erase(1)
	var rejected := not GameState.enter_map_node(1, 0, 0)
	GameConfig.shops[1] = shop_config
	if not _check(rejected and MapManager.current_map_node == null and not MapManager.find_map_node(1, 0, 0).visited, "bad shop config must not consume the node"):
		return
	if not _check(GameState.enter_map_node(1, 0, 0) and not GameState.enter_map_node(1, 0, 0), "shop entry must happen once"):
		return
	BackpackManager.set_grid_purchase_mode(true)
	if not _check(GameState.leave_current_node() and not GameState.leave_current_node() and not BackpackManager.is_grid_purchase_mode, "shop exit must close grid purchase mode once"):
		return
	if not _check(GameState.enter_map_node(1, 1, 1), "forge entry must succeed"):
		return
	var material: Equipment = BackpackManager.backpack_equip.values()[0]
	if not _check(BackpackManager.try_select_forge_material(material.instance_id, Vector2i.ZERO).success and GameState.leave_current_node() and BackpackManager.get_forge_materials().is_empty() and BackpackManager.get_equipment(material.instance_id) != null, "forge exit must cancel selection and retain the original equipment"):
		return
	if not _check(GameState.enter_map_node(1, 2, 0) and GameState.leave_current_node(), "next shop must follow the chosen connection"):
		return
	var battle_path: String = Scenes.scenes.battle.value
	Scenes.scenes.battle.value = "res://missing_battle.tscn"
	rejected = not GameState.enter_map_node(1, 3, 0)
	Scenes.scenes.battle.value = battle_path
	if not _check(rejected and not MapManager.find_map_node(1, 3, 0).visited and GameState.phase == RunState.Phase.MAP, "missing battle scene must preserve progress"):
		return
	if not _check(GameState.enter_map_node(1, 3, 0) and not GameState.enter_map_node(1, 3, 0), "battle entry must reject repeats") or not await _wait_phase(RunState.Phase.BATTLE):
		return
	GameState.record_collected_gold(17)
	BackpackManager.set_gold(321)
	CombatManager.end_battle(true)
	var first_result := CombatManager.last_result
	var first_settlement := GameState.get_settlement()
	if not _check(first_settlement != null and first_settlement.next_action == RunSettlement.Action.RETURN_TO_MAP, "non-final battle must settle for return to map"):
		return
	if not _check(not GameState.complete_battle(first_result, initial_run_id) and not GameState.complete_battle(BattleResult.new(), initial_run_id), "duplicate and unauthenticated results must be ignored"):
		return
	var view := get_tree().current_scene.get_node("BattleUI/GameOver") as GameOver
	if not _check(not GameState.continue_run(first_settlement.settlement_id + 1), "an unknown settlement token must be rejected"):
		return
	view.update_text()
	if not _check(view.visible and MapManager.current_map_id == 1, "battle result UI must display without advancing map"):
		return
	if not _check(GameState.continue_run(first_settlement.settlement_id) and not GameState.continue_run(first_settlement.settlement_id), "continue must consume a settlement once") or not await _wait_phase(RunState.Phase.MAP):
		return
	if not _check(BackpackManager.gold == 321 and GameState.total_gold_collected == 17 and MapManager.current_map_node.layer_index == 3, "return to map must retain run progress and inventory"):
		return
	# 下一张地图只有商店，覆盖非战斗终点与未手工编排的地图布局。
	var next_node := MapNodeData.from_dict({"MapID": 2, "LayerIndex": 0, "NodeIndex": 0, "NodeType": "shop", "ConfigID": 1})
	GameConfig.map_nodes[2] = {0: {0: next_node}}
	if not _check(GameState.enter_map_node(1, 4, 0) and GameState.leave_current_node(), "final shop must produce a settlement"):
		return
	var next_settlement := GameState.get_settlement()
	if not _check(next_settlement.next_action == RunSettlement.Action.NEXT_MAP and MapManager.current_map_id == 1, "next map must be an explicit unconsumed action"):
		return
	next_settlement.next_map_id = 99
	if not _check(GameState.get_settlement().next_map_id == 2, "UI snapshot mutation cannot alter the official next map"):
		return
	next_node.map_id = 99
	rejected = not GameState.continue_run(next_settlement.settlement_id)
	next_node.map_id = 2
	if not _check(rejected and MapManager.current_map_id == 1 and GameState.phase == RunState.Phase.SETTLEMENT, "bad next-map config must preserve settlement"):
		return
	var equipment_ids := BackpackManager._inventory.items.keys()
	if not _check(GameState.continue_run(next_settlement.settlement_id), "valid next-map request must succeed") or not await _wait_phase(RunState.Phase.MAP):
		return
	if not _check(MapManager.current_map_id == 2 and BackpackManager.gold == 321 and equipment_ids == BackpackManager._inventory.items.keys() and GameState.run_id == initial_run_id, "next map must preserve inventory instances, balance and run identity"):
		return
	var map_view := get_tree().current_scene.get_node("PanelManager/Map").get_child(0) as Map
	if not _check(map_view.map_node_buttons.size() == 1 and map_view.map_node_buttons[0].map_id == 2, "un-authored maps must render the configured nodes"):
		return
	if not _check(GameState.enter_map_node(2, 0, 0) and GameState.leave_current_node() and GameState.get_settlement().next_action == RunSettlement.Action.END_RUN, "last shop on final map must end the run"):
		return
	if not _check(GameState.return_to_menu(), "completed run must return to menu") or not await _wait_phase(RunState.Phase.MENU):
		return
	GameConfig.map_nodes.erase(2)
	if not _check(GameState.start_run(2), "new character must start a new run") or not await _wait_phase(RunState.Phase.MAP):
		return
	if not _check(GameState.enter_map_node(1, 0, 0) and GameState.leave_current_node() and GameState.enter_map_node(1, 1, 0), "new run must enter battle through reachable nodes") or not await _wait_phase(RunState.Phase.BATTLE):
		return
	# 无 HUD 也必须结算；旧局结果不能覆盖当前战斗。
	get_tree().current_scene.get_node("BattleUI").free()
	if not _check(not GameState.complete_battle(first_result, initial_run_id) and GameState.phase == RunState.Phase.BATTLE, "stale run results must not settle a new battle"):
		return
	GameState.record_collected_gold(9)
	BackpackManager.set_gold(12)
	CombatManager.end_battle(false)
	var loss := GameState.get_settlement()
	var failed_run_id := GameState.run_id
	if not _check(loss != null and loss.next_action == RunSettlement.Action.RETRY and loss.collected_gold == 9, "battle without HUD must still create a defeat settlement"):
		return
	if not _check(GameState.retry_run(loss.settlement_id) and not GameState.retry_run(loss.settlement_id), "retry must start only once") or not await _wait_phase(RunState.Phase.MAP):
		return
	if not _check(GameState.current_character_id == 2 and GameState.run_id > failed_run_id and GameState.total_gold_collected == 0 and BackpackManager.gold == 999 and BackpackManager.grid_cost == 10 and MapManager.current_map_node == null and GameState.get_settlement() == null, "retry must preserve character and reset run, inventory and map state"):
		return
	if not _check(not GameState.continue_run(first_settlement.settlement_id) and not GameState.retry_run(loss.settlement_id), "old UI actions cannot affect the fresh run"):
		return
	if not _check(GameState.return_to_menu(), "retry can leave for menu") or not await _wait_phase(RunState.Phase.MENU):
		return
	print("PASS: real run navigation, duplicate requests, scene/config failure preservation, shop/forge exits, next map, no-HUD settlement, stale results and retry")
	get_tree().quit(0)


func _wait_phase(expected: RunState.Phase) -> bool:
	for attempt in 100:
		await get_tree().create_timer(0.02).timeout
		if GameState.phase == expected and not GameState.is_busy():
			return true
	return _check(false, "transition timeout: expected %s, actual %s, error %s" % [expected, GameState.phase, GameState.last_error])


func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("RUN NAVIGATION TEST FAILED: " + message)
		get_tree().quit(1)
	return ok
