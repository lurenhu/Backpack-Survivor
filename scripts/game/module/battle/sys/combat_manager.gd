extends Node
## 单例：战斗管理器，驱动波次生成、敌人生成和战斗结果处理

signal update_wave_show(wave_index: int)
signal gold_collected(amount: int)
signal enemy_killed(enemy: Node, gold_reward: int)
## 伤害已处理完成，监听者仅消费结果，不再负责扣血。
signal damage_applied(result: DamageResult)
signal battle_ended(won: bool)
## 发射器提交子弹生成参数时触发，由当前战斗场景的 BulletSpawner 接收。
signal projectile_requested(request: ProjectileSpawnRequest)

var is_battle_active: bool = false
var _spawn_parent: Node = null
var _pickup_parent: Node = null
var _damage_system: DamageSystem = DamageSystem.new()

@export var PICKUP_SCENE_PATH: PackedScene = preload("res://scene/battle/pick_up.tscn")
const GOLD_PICKUP_CONFIG_ID: int = 1

## 波次数据：每个元素为 {limit: float, spawners: Array[EnemySpawner]}
var _waves: Array = []
var _current_wave_index: int = -1
var _spawn_points: Array[Marker2D] = []

#region 公开方法

## 战斗中的统一伤害入口；无效、被拒绝或战斗结束后的请求不会发出通知。
func apply_damage(request: DamageRequest) -> DamageResult:
	if not is_battle_active:
		return DamageResult.new()
	var result := _damage_system.apply_damage(request)
	if result.applied:
		damage_applied.emit(result)
	return result


## 根据 battle.csv 的嵌套数据初始化波次，为每条配置创建一个 EnemySpawner
func setup_from_config(wave_data: Dictionary) -> void:
	_waves.clear()
	_current_wave_index = -1

	var sorted_ids: Array = wave_data.keys()
	sorted_ids.sort()

	for wave_id in sorted_ids:
		var monster_dict: Dictionary = wave_data[wave_id]
		var limit: float = 0.0
		var spawners: Array[EnemySpawner] = []

		for monster_id in monster_dict:
			var config: BattleConfigData = monster_dict[monster_id]
			limit = config.limit
			var spawner := EnemySpawner.new()
			spawner.setup(config)
			spawner.set_spawn_points(_spawn_points)
			spawners.append(spawner)

		_waves.append({"limit": limit, "spawners": spawners})

	if enemy_killed.is_connected(_on_enemy_killed):
		enemy_killed.disconnect(_on_enemy_killed)
	enemy_killed.connect(_on_enemy_killed)
	is_battle_active = true

## 每帧更新战斗逻辑：根据累计时间定位波次，推动敌人生成器生成敌人
func tick_combat(delta: float, elapsed_time: float) -> void:
	if not is_battle_active:
		return
	if _waves.is_empty():
		return

	# 根据累计时间确定当前应处于哪个波次
	var cumulative: float = 0.0
	var target_wave: int = -1
	for i in range(_waves.size()):
		cumulative += _waves[i]["limit"]
		if elapsed_time < cumulative:
			target_wave = i
			break

	if target_wave == -1:
		_current_wave_index = _waves.size()
		return

	# 首次进入第一个波次
	if _current_wave_index == -1:
		_current_wave_index = 0
		update_wave_show.emit(_current_wave_index)

	# 推进到目标波次（处理跳帧等边缘情况）
	while _current_wave_index < target_wave:
		_current_wave_index += 1
		update_wave_show.emit(_current_wave_index)

	# 推动当前波次下的所有敌人生成器
	var spawners: Array[EnemySpawner] = _waves[_current_wave_index]["spawners"]
	if _spawn_parent != null:
		for spawner: EnemySpawner in spawners:
			var mid: int = spawner.tick(delta)
			if mid != 0:
				var enemy: Node = spawner.spawn(_spawn_parent)
				if enemy != null:
					enemy.add_to_group("enemies")

## 注册敌人生成的父节点
func register_spawn_parent(parent: Node) -> void:
	_spawn_parent = parent

## 注册敌人生成点并同步到所有已创建的 EnemySpawner
func register_spawn_points(spawn_points: Array[Marker2D]) -> void:
	_spawn_points = spawn_points
	for wave_data in _waves:
		for spawner in wave_data["spawners"]:
			spawner.set_spawn_points(spawn_points)

## 注册拾取物生成的父节点
func register_pickup_parent(parent: Node) -> void:
	_pickup_parent = parent

#endregion

#region 私有功能

## 敌人死亡时：移除组归属，生成金币拾取物，检查战斗胜利
func _on_enemy_killed(enemy: Node, gold_reward: int) -> void:
	enemy.remove_from_group("enemies")
	if _pickup_parent != null:
		call_deferred("_spawn_gold_pickup", enemy.global_position, gold_reward)
	call_deferred("_check_battle_victory")

## 延迟生成金币拾取物（避免在物理回调中修改碰撞状态）
func _spawn_gold_pickup(global_position: Vector2, value: int) -> void:
	if not is_battle_active:
		return
	if _pickup_parent == null or not is_instance_valid(_pickup_parent):
		return
	var pickup: Pickup = PICKUP_SCENE_PATH.instantiate() as Pickup
	pickup.global_position = global_position
	_pickup_parent.add_child(pickup)
	pickup.setup(GOLD_PICKUP_CONFIG_ID)
	pickup.value = value

## 检查战斗胜利条件：所有波次已结束且无存活敌人
func _check_battle_victory() -> void:
	if not is_battle_active:
		return
	if _current_wave_index < _waves.size():
		return
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		end_battle(true)

#endregion

#region 信号回调

## 结束当前战斗
func end_battle(won: bool) -> void:
	if not is_battle_active:
		return
	is_battle_active = false
	battle_ended.emit(won)

#endregion
