extends Node

const BATTLE_SCENE := preload("res://scene/battle/battle.tscn")
const ENEMY_SCENE := preload("res://scene/battle/entities/enemy_slime.tscn")
const HUD_SCENE := preload("res://scene/battle/battle_ui.tscn")

var _results: Array[DamageResult] = []
var _battle_results: Array[bool] = []


class DamageTarget extends Node2D:
	var current_hp: float = 30.0
	var accepts_damage: bool = true
	var calls: int = 0

	func take_damage(amount: float) -> bool:
		calls += 1
		if not accepts_damage:
			return false
		current_hp = maxf(current_hp - amount, 0.0)
		return true


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _test_damage_system():
		return
	if not await _test_battle_damage_flow():
		return
	print("PASS: damage validation, no-HUD combat, result snapshots, HUD updates and defeat lifecycle")
	get_tree().quit(0)


func _test_damage_system() -> bool:
	var system := DamageSystem.new()
	var target := DamageTarget.new()
	add_child(target)
	target.position = Vector2(50.0, 80.0)
	for request in [null, DamageRequest.new(), DamageRequest.create(null, self, 10.0)]:
		if not _assert(not system.apply_damage(request).applied, "missing or unsupported targets must be rejected"):
			return false
	for amount in [0.0, -10.0, NAN, INF]:
		if not _assert(not system.apply_damage(DamageRequest.create(null, target, amount)).applied, "invalid amounts must be rejected"):
			return false
	if not _assert(target.calls == 0 and target.current_hp == 30.0, "invalid requests must not reach take_damage"):
		return false

	var result := system.apply_damage(DamageRequest.create(self, target, 10.5))
	if not _assert(result.applied and result.source == self and result.target == target, "accepted damage must retain its source and target"):
		return false
	if not _assert(result.actual_damage == 10.5 and result.remaining_hp == 19.5 and not result.killed, "result must describe the actual health change"):
		return false
	target.accepts_damage = false
	result = system.apply_damage(DamageRequest.create(null, target, 5.0))
	if not _assert(not result.applied and result.remaining_hp == 19.5 and target.current_hp == 19.5, "rejected hits must preserve health"):
		return false
	target.accepts_damage = true
	result = system.apply_damage(DamageRequest.create(null, target, 100.0))
	if not _assert(result.killed and result.actual_damage == 19.5 and result.remaining_hp == 0.0, "overkill must report only the health actually lost"):
		return false
	var calls := target.calls
	if not _assert(not system.apply_damage(DamageRequest.create(null, target, 1.0)).applied and target.calls == calls, "dead targets must reject repeated hits"):
		return false
	var stale_request := DamageRequest.create(null, target, 1.0)
	target.free()
	if not _assert(not system.apply_damage(stale_request).applied, "freed targets must be safe"):
		return false
	if not _assert(result.world_position == Vector2(50.0, 80.0) and result.actual_damage == 19.5, "result snapshots must survive target destruction"):
		return false

	var queued_target := DamageTarget.new()
	add_child(queued_target)
	queued_target.queue_free()
	return _assert(not system.apply_damage(DamageRequest.create(null, queued_target, 1.0)).applied, "targets queued for deletion must reject damage")


func _test_battle_damage_flow() -> bool:
	GameState.start_new_run(1)
	for map_node in MapManager.current_map_nodes:
		if map_node.node_type == "battle":
			MapManager.current_map_node = map_node
			break
	if not _assert(MapManager.current_map_node != null, "test needs a configured battle node"):
		return false
	var battle := BATTLE_SCENE.instantiate()
	var original_hud := battle.get_node("BattleUI")
	battle.remove_child(original_hud)
	original_hud.free()
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	battle.get_node("Node/PhantomCamera2D").show_viewfinder_in_play = false
	add_child(battle)
	var player := battle.get_node("Node/Player") as Player
	var stale_target := Node2D.new()
	battle.add_child(stale_target)
	var stale_request := DamageRequest.create(null, stale_target, 1.0)
	stale_target.free()
	if not _assert(not CombatManager.apply_damage(stale_request).applied, "manager must safely reject freed targets"):
		return false
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.setup(1)
	battle.get_node("EnemyContainer").add_child(enemy)
	enemy.add_to_group("enemies")
	enemy.current_hp = 100.0
	enemy.global_position = Vector2(100.0, 200.0)
	CombatManager.damage_applied.connect(_on_damage_applied)
	CombatManager.battle_ended.connect(_on_battle_ended)

	var result := CombatManager.apply_damage(DamageRequest.create(null, player, 10.5))
	if not _assert(result.applied and player.current_hp == result.remaining_hp and _results.size() == 1, "a real player must take damage without a HUD"):
		return false
	var remaining_hp := player.current_hp
	var blocked := CombatManager.apply_damage(DamageRequest.create(enemy, player, 10.0))
	if not _assert(not blocked.applied and player.current_hp == remaining_hp and _results.size() == 1, "invulnerability must suppress both damage and notification"):
		return false

	var weapon := player.weapon_anchor.get_child(0) as RotateWeapon
	weapon._on_body_entered(enemy)
	if not _assert(is_equal_approx(enemy.current_hp, 100.0 - weapon._attack_power), "melee attacks must use the new damage entry point"):
		return false
	player.hit_timer.stop()
	enemy._on_damage_area_body_entered(player)
	if not _assert(is_equal_approx(player.current_hp, remaining_hp - enemy.attrs.get_value(AttrType.Type.ATK)), "enemy contact attacks must apply damage without a HUD"):
		return false

	var hud := HUD_SCENE.instantiate() as BattleUI
	battle.add_child(hud)
	player.hit_timer.stop()
	result = CombatManager.apply_damage(DamageRequest.create(enemy, player, 2.5))
	if not _assert(result.applied and hud.get_node("HealthBar/ProgressBar").value == player.current_hp, "HUD must observe health after damage has been applied"):
		return false
	if not _assert(hud.get_node("DamageShow").get_child_count() == 1, "a successful hit should create one damage label"):
		return false
	remaining_hp = player.current_hp
	CombatManager.apply_damage(DamageRequest.create(enemy, player, 2.5))
	if not _assert(player.current_hp == remaining_hp and hud.get_node("DamageShow").get_child_count() == 1, "an invulnerable hit must not create a label or alter health"):
		return false

	result = CombatManager.apply_damage(DamageRequest.create(weapon, enemy, 1000.0))
	if not _assert(result.killed and enemy.current_hp == 0.0, "enemy death must be handled by the target"):
		return false
	var result_count := _results.size()
	if not _assert(not CombatManager.apply_damage(DamageRequest.create(weapon, enemy, 1.0)).applied and _results.size() == result_count, "a dying enemy must not produce duplicate results"):
		return false
	await get_tree().process_frame
	if not _assert(not is_instance_valid(enemy), "dead enemies must be released"):
		return false
	# 重播显示结果不应扣血，且不应访问已销毁目标的位置。
	hud._on_damage_applied(result)
	if not _assert(player.current_hp == remaining_hp and result.world_position == Vector2(100.0, 200.0), "HUD must consume snapshots without changing combat state"):
		return false
	hud.free()

	player.hit_timer.stop()
	result = CombatManager.apply_damage(DamageRequest.create(null, player, 10000.0))
	if not _assert(result.killed and not CombatManager.is_battle_active and _battle_results == [false], "player death without a HUD must end battle once"):
		return false
	CombatManager.end_battle(false)
	result_count = _results.size()
	blocked = CombatManager.apply_damage(DamageRequest.create(null, player, 1.0))
	if not _assert(not blocked.applied and _battle_results == [false] and _results.size() == result_count, "ended battles must reject new damage and duplicate completion"):
		return false
	CombatManager.damage_applied.disconnect(_on_damage_applied)
	CombatManager.battle_ended.disconnect(_on_battle_ended)
	battle.queue_free()
	await get_tree().process_frame
	return true


func _on_damage_applied(result: DamageResult) -> void:
	_results.append(result)


func _on_battle_ended(result: BattleResult) -> void:
	_battle_results.append(result.won)


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("DAMAGE SYSTEM TEST FAILED: %s" % message)
	get_tree().quit(1)
	return false
