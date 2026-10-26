extends Node

const FIXTURE := preload("res://tests/config/config_test_fixture.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var good := FIXTURE.tables()
	var bad := good.duplicate(true)
	bad.shops[0].EquipmentIDs = "999"
	var initial_snapshot := GameConfig._snapshot
	var initial_loader := GameConfig._loader
	var balance := BackpackManager.gold
	GameConfig._snapshot = ConfigSnapshot.new()
	GameConfig._loaded = false
	GameConfig._loader = FIXTURE.loader(bad)
	if not _check(not GameConfig.ensure_loaded() and not GameConfig.is_ready() and GameConfig.equipment.is_empty() and GameConfig.map_nodes.is_empty(), "first failure must leave every formal table empty and not ready"):
		return
	if not _check(not GameConfig.ensure_loaded() and GameConfig.get_diagnostics().contains("EquipmentIDs"), "failed initialization must remain retryable with diagnostics"):
		return
	if not _check(not GameState.show_character_select() and not GameState.start_run(1) and GameState.phase == RunState.Phase.MENU and BackpackManager.gold == balance, "invalid configuration must block selection/start without changing gameplay"):
		return
	# 重试也必须走同一个配置就绪检查，不只校验角色存在。
	GameState._run.phase = RunState.Phase.SETTLEMENT
	GameState._run.character_id = 1
	GameState._settlement = RunFlow.settle(GameState._run, false, false, 0)
	GameState._settlement.settlement_id = 1
	if not _check(not GameState.retry_run(1) and GameState.phase == RunState.Phase.SETTLEMENT and BackpackManager.gold == balance, "retry must preserve the old settlement on configuration failure"):
		return
	GameState._run = RunState.new()
	GameState._settlement = null
	GameConfig._loader = FIXTURE.loader(good)
	if not _check(GameConfig.ensure_loaded() and GameConfig.is_ready() and GameConfig.equipment.size() == 28 and not GameConfig.map_nodes.is_empty(), "corrected input must publish all tables and recover"):
		return
	var published := GameConfig._snapshot
	var item: EquipmentData = GameConfig.equipment[1]
	bad.equipment[0].Name = "SHOULD NEVER BE PUBLISHED"
	var failed := GameConfig.load_configuration(FIXTURE.loader(bad))
	if not _check(not failed.success and failed.snapshot == null and GameConfig.is_ready() and GameConfig._snapshot == published and GameConfig.equipment[1] == item and item.name != "SHOULD NEVER BE PUBLISHED", "a failed replacement must preserve the complete previous snapshot"):
		return
	GameConfig._loader = FIXTURE.loader(bad)
	if not _check(GameConfig.ensure_loaded() and GameConfig._snapshot == published, "ready configuration must not reload just because another lookup occurs"):
		return
	var missing := good.duplicate(true)
	missing.erase("characters")
	var result := FIXTURE.loader(missing).load_all()
	if not _check(not result.success and FIXTURE.has_issue(result, &"invalid_table"), "unreadable table must reject the full candidate"):
		return
	if not _check(GameConfig._snapshot == published and BackpackManager.gold == balance, "standalone validation must have no gameplay side effects"):
		return
	GameConfig._snapshot = initial_snapshot
	GameConfig._loader = initial_loader
	GameConfig._loaded = true
	print("PASS: no partial publication, initialization failure/retry, start/retry gates, preserved previous snapshot and isolated validation")
	get_tree().quit(0)


func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("CONFIG LOADING TEST FAILED: " + message)
		get_tree().quit(1)
	return ok
