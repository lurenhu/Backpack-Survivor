extends Node
## 全局战斗入口；单场状态只在 start_battle 到 cleanup 之间有效。

enum State {IDLE, RUNNING, FINISHED}

signal update_wave_show(wave_index: int)
signal gold_collected(amount: int)
signal enemy_killed(enemy: Node, gold_reward: int)
signal damage_applied(result: DamageResult)
signal battle_ended(result: BattleResult)
## 结束或中途清理时先停止场景实体，再通知结算。
signal battle_stopped()
signal projectile_requested(request: ProjectileSpawnRequest)

const PICKUP_SCENE: PackedScene = preload("res://scene/battle/pick_up.tscn")
const GOLD_PICKUP_CONFIG_ID: int = 1

var state: State:
	get:
		return _state
var is_battle_active: bool:
	get:
		return state == State.RUNNING
var battle_id: int:
	get:
		return _battle_id
var elapsed_time: float:
	get:
		return _elapsed_time
var last_result: BattleResult

var _state: State = State.IDLE
var _battle_id: int = 0
var _elapsed_time: float = 0.0
var _config_id: int = 0
var _context: BattleContext
var _damage_system := DamageSystem.new()
## 每项为 {limit: float, spawners: Array[EnemySpawner]}。
var _waves: Array[Dictionary] = []
var _current_wave_index: int = -1
var _wave_elapsed: float = 0.0
var _enemies: Dictionary[int, Enemy] = {}
var _owner_exit_callback: Callable


## 调用者先连接事件；验证完毕后才开放战斗操作。开始新战斗前必须清理旧场景。
func start_battle(config_id: int, context: BattleContext) -> bool:
	if state != State.IDLE or _context != null or context == null or not context.is_valid():
		return false
	var wave_data: Dictionary = GameConfig.battles.get(config_id, {})
	if not _validate_waves(wave_data):
		return false
	_battle_id += 1
	_config_id = config_id
	_context = context
	_elapsed_time = 0.0
	_wave_elapsed = 0.0
	last_result = null
	_build_waves(wave_data)
	_current_wave_index = 0
	_context.enemy_container.child_entered_tree.connect(_on_enemy_entered)
	_context.enemy_container.child_exiting_tree.connect(_on_enemy_exiting)
	for child in _context.enemy_container.get_children():
		_on_enemy_entered(child)
	enemy_killed.connect(_on_enemy_killed)
	_owner_exit_callback = _on_owner_exiting.bind(battle_id)
	_context.scene_root.tree_exiting.connect(_owner_exit_callback)
	_state = State.RUNNING
	update_wave_show.emit(_current_wave_index)
	return true


func tick_combat(delta: float) -> void:
	if not is_battle_active or not is_finite(delta) or delta < 0.0:
		return
	if not _context.is_valid():
		cleanup()
		return
	_elapsed_time += delta
	var id := battle_id
	var remaining := delta
	# 分段推进，跨越波次的帧也会处理每个波次的生成器。
	while _current_wave_index < _waves.size():
		var wave: Dictionary = _waves[_current_wave_index]
		var step := minf(remaining, float(wave.limit) - _wave_elapsed)
		for spawner: EnemySpawner in wave.spawners:
			if spawner.tick(step) != 0:
				spawner.spawn(_context.enemy_container)
		_wave_elapsed += step
		remaining -= step
		if _wave_elapsed < float(wave.limit):
			break
		_wave_elapsed = 0.0
		_current_wave_index += 1
		if _current_wave_index < _waves.size():
			update_wave_show.emit(_current_wave_index)
			if not is_current_battle(id):
				return
		if remaining <= 0.0:
			break
	_check_battle_victory(battle_id)


func apply_damage(request: DamageRequest) -> DamageResult:
	if not is_battle_active:
		return DamageResult.new()
	if request == null or not is_instance_valid(request.target) or not _context.owns(request.target):
		return DamageResult.new()
	if request.source != null:
		if not is_instance_valid(request.source) or not _context.owns(request.source):
			return DamageResult.new()
	var result := _damage_system.apply_damage(request)
	if result.applied:
		damage_applied.emit(result)
	return result


## 仅当前场景中的发射器可以提交请求，延迟实例化还需复核战斗编号。
func request_projectile(request: ProjectileSpawnRequest, source: Node) -> void:
	if is_battle_active and _context.owns(source):
		projectile_requested.emit(request)


func is_current_battle(id: int) -> bool:
	return is_battle_active and id == battle_id


func owns_node(node: Node) -> bool:
	return is_battle_active and _context.owns(node)


func end_battle(won: bool) -> void:
	if not is_battle_active:
		return
	_state = State.FINISHED
	var result := BattleResult.new()
	result.battle_id = battle_id
	result.config_id = _config_id
	result.won = won
	result.reason = &"victory" if won else &"defeat"
	result.elapsed_time = elapsed_time
	last_result = result
	battle_stopped.emit()
	battle_ended.emit(result)


## 中途退出也走这里；不生成胜负结果，不销毁由场景拥有的实体。
func cleanup() -> void:
	if state == State.IDLE and _context == null:
		return
	var had_context := _context != null
	_state = State.IDLE
	_battle_id += 1
	if had_context:
		battle_stopped.emit()
		if is_instance_valid(_context.scene_root) and _context.scene_root.tree_exiting.is_connected(_owner_exit_callback):
			_context.scene_root.tree_exiting.disconnect(_owner_exit_callback)
		if is_instance_valid(_context.enemy_container):
			_context.enemy_container.child_entered_tree.disconnect(_on_enemy_entered)
			_context.enemy_container.child_exiting_tree.disconnect(_on_enemy_exiting)
		_context.clear()
	_context = null
	_owner_exit_callback = Callable()
	if enemy_killed.is_connected(_on_enemy_killed):
		enemy_killed.disconnect(_on_enemy_killed)
	for wave in _waves:
		for spawner: EnemySpawner in wave.spawners:
			spawner.cleanup()
	_waves.clear()
	_enemies.clear()
	_current_wave_index = -1
	_wave_elapsed = 0.0
	_elapsed_time = 0.0
	_config_id = 0
	last_result = null


func can_start_config(config_id: int) -> bool:
	return _validate_waves(GameConfig.battles.get(config_id, {}))


func _validate_waves(wave_data: Dictionary) -> bool:
	if wave_data.is_empty():
		return false
	for monster_data: Dictionary in wave_data.values():
		if monster_data.is_empty():
			return false
		var limit: float = -1.0
		for config: BattleConfigData in monster_data.values():
			if config == null or not is_finite(config.limit) or config.limit <= 0.0:
				return false
			if not is_finite(config.interval) or config.interval < 0.0 or config.count < 0:
				return false
			if not GameConfig.monsters.has(config.monster_id):
				return false
			if limit >= 0.0 and not is_equal_approx(limit, config.limit):
				return false
			limit = config.limit
	return true


func _build_waves(wave_data: Dictionary) -> void:
	var ids := wave_data.keys()
	ids.sort()
	for wave_id in ids:
		var spawners: Array[EnemySpawner] = []
		var limit: float = 0.0
		for config: BattleConfigData in wave_data[wave_id].values():
			limit = config.limit
			var spawner := EnemySpawner.new()
			spawner.setup(config)
			spawner.set_spawn_points(_context.spawn_points)
			spawners.append(spawner)
		_waves.append({"limit": limit, "spawners": spawners})


func _on_enemy_entered(node: Node) -> void:
	if node is Enemy:
		_enemies[node.get_instance_id()] = node
		node.add_to_group("enemies")


func _on_enemy_exiting(node: Node) -> void:
	_enemies.erase(node.get_instance_id())
	_check_battle_victory.call_deferred(battle_id)


func _on_enemy_killed(enemy: Node, gold_reward: int) -> void:
	if not is_battle_active or not is_instance_valid(enemy) or not _enemies.has(enemy.get_instance_id()):
		return
	_enemies.erase(enemy.get_instance_id())
	enemy.remove_from_group("enemies")
	_spawn_gold_pickup.call_deferred(enemy.global_position, gold_reward, battle_id)
	_check_battle_victory.call_deferred(battle_id)


func _spawn_gold_pickup(position: Vector2, value: int, id: int) -> void:
	if not is_current_battle(id) or not _context.is_valid() or value <= 0:
		return
	var pickup := PICKUP_SCENE.instantiate() as Pickup
	_context.pickup_container.add_child(pickup)
	pickup.global_position = position
	pickup.setup(GOLD_PICKUP_CONFIG_ID)
	pickup.value = value


func _check_battle_victory(id: int) -> void:
	if is_current_battle(id) and _current_wave_index >= _waves.size() and _enemies.is_empty():
		end_battle(true)


func _on_owner_exiting(id: int) -> void:
	if id == battle_id:
		cleanup()
