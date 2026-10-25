extends Node

const FIXTURE := preload("res://tests/battle/battle_test_context.gd")
const BATTLE_SCENE := preload("res://scene/battle/battle.tscn")
const ENEMY_SCENE := preload("res://scene/battle/entities/enemy_slime.tscn")
const PICKUP_SCENE := preload("res://scene/battle/pick_up.tscn")
const CONFIG_ID: int = 900001

var _results: Array[BattleResult] = []
var _waves: Array[int] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	CombatManager.battle_ended.connect(_on_ended)
	CombatManager.update_wave_show.connect(_on_wave)
	if not _test_start_validation():
		return
	if not await _test_early_and_late_kills():
		return
	if not await _test_cleanup_and_stale_callbacks():
		return
	if not await _test_scene_stop_and_reentry():
		return
	if not await _test_retry_navigation():
		return
	GameConfig.battles.erase(CONFIG_ID)
	print("PASS: battle startup, early/late victory, stale callbacks, cleanup, scene freeze, retry and map/battle/menu transitions")
	get_tree().quit(0)


func _new_context(count: int = 0) -> BattleContext:
	var root := Node2D.new()
	root.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(root)
	GameConfig.battles[CONFIG_ID] = {1: {1: BattleConfigData.from_dict({
		"ID": CONFIG_ID, "WaveID": 1, "MonsterID": 1,
		"Limit": 1.0, "Interval": 0.1, "Count": count,
	})}}
	return FIXTURE.create(root)


func _test_start_validation() -> bool:
	var context := _new_context()
	var root := context.scene_root
	if not _assert(not CombatManager.start_battle(CONFIG_ID, BattleContext.new()), "missing scene references must reject startup"):
		return false
	if not _assert(not CombatManager.start_battle(-1, context), "missing config must reject startup"):
		return false
	var config: BattleConfigData = GameConfig.battles[CONFIG_ID][1][1]
	config.limit = 0.0
	if not _assert(not CombatManager.start_battle(CONFIG_ID, context) and not CombatManager.is_battle_active, "invalid durations must leave battle idle"):
		return false
	config.limit = 1.0
	# 多波次跨帧推进，零怪波次仍必须按时间结束。
	GameConfig.battles[CONFIG_ID][2] = {1: config}
	if not _assert(CombatManager.start_battle(CONFIG_ID, context), "valid context must start"):
		return false
	var id := CombatManager.battle_id
	if not _assert(not CombatManager.start_battle(CONFIG_ID, context) and CombatManager.battle_id == id, "duplicate start must not replace active state"):
		return false
	CombatManager.tick_combat(1.5)
	if not _assert(CombatManager.is_battle_active and _waves == [0, 1], "crossing a wave boundary must advance the wave once"):
		return false
	CombatManager.tick_combat(0.5)
	if not _assert(_results.size() == 1 and _results[0].won and _results[0].elapsed_time == 2.0, "empty final wave must finish on time"):
		return false
	var snapshot := _results[0]
	CombatManager.end_battle(false)
	CombatManager.cleanup()
	CombatManager.cleanup()
	root.free()
	return _assert(_results.size() == 1 and snapshot.battle_id == id and snapshot.reason == &"victory", "completion is once-only and snapshots survive cleanup")


func _test_early_and_late_kills() -> bool:
	for early in [true, false]:
		var context := _new_context(1)
		var root := context.scene_root
		var result_count := _results.size()
		if not _assert(CombatManager.start_battle(CONFIG_ID, context), "kill test must start"):
			return false
		CombatManager.tick_combat(0.1)
		if not _assert(context.enemy_container.get_child_count() == 1, "configured enemy must spawn"):
			return false
		var enemy := context.enemy_container.get_child(0) as Enemy
		# 整棵树的敌人组不能影响本场胜利判定。
		var unrelated := Node2D.new()
		add_child(unrelated)
		unrelated.add_to_group("enemies")
		if not early:
			CombatManager.tick_combat(0.9)
			if not _assert(CombatManager.is_battle_active, "time expiry must wait for the last living enemy"):
				return false
		CombatManager.apply_damage(DamageRequest.create(null, enemy, 10000.0))
		await get_tree().process_frame
		if early:
			if not _assert(CombatManager.is_battle_active and _results.size() == result_count, "early clear must wait for wave time"):
				return false
			CombatManager.tick_combat(0.9)
		if not _assert(_results.size() == result_count + 1 and _results.back().won, "time expiry and final death must both trigger victory checks"):
			return false
		root.free()
		unrelated.free()
		if not _assert(CombatManager.state == CombatManager.State.IDLE and context.scene_root == null, "owner exit must release battle references"):
			return false
	return true


func _test_cleanup_and_stale_callbacks() -> bool:
	var old_context := _new_context(1)
	var old_root := old_context.scene_root
	if not _assert(CombatManager.start_battle(CONFIG_ID, old_context), "old battle must start"):
		return false
	CombatManager.tick_combat(0.1)
	var enemy := old_context.enemy_container.get_child(0) as Enemy
	CombatManager.apply_damage(DamageRequest.create(null, enemy, 10000.0))
	var bullets := Node2D.new()
	old_root.add_child(bullets)
	var spawner := BulletSpawner.new()
	old_root.add_child(spawner)
	spawner.setup(bullets)
	spawner.spawn(_projectile())
	var old_id := CombatManager.battle_id
	var old_spawner: EnemySpawner = CombatManager._waves[0].spawners[0]
	var result_count := _results.size()
	CombatManager.cleanup()
	if not _assert(old_context.scene_root == null and old_spawner._spawn_points.is_empty(), "cleanup must release context and generator references"):
		return false
	var context := _new_context()
	var root := context.scene_root
	if not _assert(CombatManager.start_battle(CONFIG_ID, context), "next battle must start"):
		return false
	var new_id := CombatManager.battle_id
	CombatManager.tick_combat(0.1)
	await get_tree().process_frame
	if not _assert(bullets.get_child_count() == 0 and context.pickup_container.get_child_count() == 0, "old deferred bullets and drops must be discarded"):
		return false
	if not _assert(CombatManager.is_current_battle(new_id) and new_id != old_id and _results.size() == result_count, "old victory checks must not complete the new battle"):
		return false
	old_root.free()
	if not _assert(CombatManager.is_current_battle(new_id), "exiting an old owner must not clean up the current battle"):
		return false
	root.free()
	return _assert(CombatManager.state == CombatManager.State.IDLE and _results.size() == result_count, "early exit must clean up without a defeat result")


func _test_scene_stop_and_reentry() -> bool:
	GameState.start_new_run(1)
	for map_node in MapManager.current_map_nodes:
		if map_node.node_type == "battle":
			MapManager.current_map_node = map_node
			break
	var battle := _create_battle_scene()
	var player := battle.get_node("Node/Player") as Player
	var pickup := PICKUP_SCENE.instantiate() as Pickup
	battle.get_node("PickUpContainer").add_child(pickup)
	var balance := BackpackManager.gold
	var result_count := _results.size()
	battle.get_node("BulletSpawner").spawn(_projectile())
	CombatManager.apply_damage(DamageRequest.create(null, player, 10000.0))
	pickup._collect()
	CombatManager.end_battle(true)
	if not _assert(_results.size() == result_count + 1 and not _results.back().won and BackpackManager.gold == balance, "death must end once and reject post-end pickups"):
		return false
	await get_tree().process_frame
	if not _assert(battle.get_node("BulletContainer").get_child_count() == 0, "projectiles queued before death must not spawn after completion"):
		return false
	for path in ["Node/Player", "EnemyContainer", "BulletContainer", "PickUpContainer"]:
		if not _assert(battle.get_node(path).process_mode == Node.PROCESS_MODE_DISABLED, "finished gameplay must be disabled: " + path):
			return false
	var hud := battle.get_node("BattleUI")
	if not _assert(hud.get_node("GameOver").visible and hud.can_process(), "result UI must remain active"):
		return false
	var snapshot := CombatManager.last_result
	CombatManager.cleanup()
	if not _assert(CombatManager.state == CombatManager.State.IDLE, "battle scene exit must clean up"):
		return false
	var next_battle := _create_battle_scene()
	if not _assert(CombatManager.is_battle_active and CombatManager.elapsed_time == 0.0 and CombatManager.last_result == null, "next scene must start with fresh runtime state"):
		return false
	if not _assert(next_battle.get_node("Node/Player").can_process() and snapshot.reason == &"defeat", "new gameplay must be active and old result readable"):
		return false
	battle.free()
	if not _assert(CombatManager.is_battle_active, "old battle scene exit must not stop its replacement"):
		return false
	next_battle.free()
	return _assert(_results.size() == result_count + 1 and CombatManager.state == CombatManager.State.IDLE, "direct scene exit must not add a result")


func _test_retry_navigation() -> bool:
	# 测试节点保留在根节点下，真实场景交给 SceneManager 切换。
	var battle := _create_battle_scene()
	battle.reparent(get_tree().root)
	get_tree().current_scene = battle
	var player := battle.get_node("Node/Player") as Player
	CombatManager.apply_damage(DamageRequest.create(null, player, 10000.0))
	var game_over := battle.get_node("BattleUI/GameOver") as GameOver
	game_over.continue_button.pressed.emit()
	if not await _wait_for_scene("res://scene/main/gaming.tscn"):
		return false
	if not _assert(CombatManager.state == CombatManager.State.IDLE and GameState.total_gold_collected == 0, "retry must leave finished combat and reset the run"):
		return false
	for map_node in MapManager.current_map_nodes:
		if map_node.node_type == "battle":
			MapManager.map_node_seleceted.emit(map_node)
			break
	if not await _wait_for_scene("res://scene/battle/battle.tscn"):
		return false
	if not _assert(CombatManager.is_battle_active, "map selection must start a fresh battle"):
		return false
	GameState.change_scene("main_menu")
	if not await _wait_for_scene("res://scene/main/main_menu.tscn"):
		return false
	return _assert(CombatManager.state == CombatManager.State.IDLE, "returning to menu must clean active combat")


func _wait_for_scene(path: String) -> bool:
	for attempt in 80:
		await get_tree().create_timer(0.05).timeout
		var scene := get_tree().current_scene
		if is_instance_valid(scene) and scene.scene_file_path == path and not SceneManager._in_transition:
			return true
	return _assert(false, "scene transition timed out: " + path)


func _create_battle_scene() -> Node:
	var battle := BATTLE_SCENE.instantiate()
	battle.get_node("Node/PhantomCamera2D").show_viewfinder_in_play = false
	add_child(battle)
	return battle


func _projectile() -> ProjectileSpawnRequest:
	var spec := ProjectileSpec.new()
	spec.speed = 100.0
	return ProjectileSpawnRequest.create(Vector2.ZERO, Vector2.RIGHT, spec)


func _on_ended(result: BattleResult) -> void:
	_results.append(result)


func _on_wave(index: int) -> void:
	_waves.append(index)


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("BATTLE LIFECYCLE TEST FAILED: " + message)
	get_tree().quit(1)
	return false
