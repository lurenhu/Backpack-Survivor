class_name EnemySpawner
extends RefCounted
## 敌人生成器：一个实例对应 battle.csv 中的一条配置，负责按配置的间隔和数量生成一种怪物

var monster_id: int # 生成怪物id
var interval: float # 生成间隔时间s
var count: int # 生成数量

var _spawned: int = 0
var _timer: float = 0.0

var _spawn_points: Array[Marker2D] = []
var _scene_cache: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

#region 公开方法

## 根据一条 battle.csv 配置行初始化生成参数
func setup(config: BattleConfigData) -> void:
	monster_id = config.monster_id
	interval = config.interval
	count = config.count
	_spawned = 0
	_timer = 0.0

## 设置生成点列表（场景中的 Marker2D 节点）
func set_spawn_points(spawn_points: Array[Marker2D]) -> void:
	_spawn_points = spawn_points

## 每帧调用，返回本帧应生成的怪物ID；返回 0 表示本帧不生成；首只立即生成，后续按 interval 间隔
func tick(delta: float) -> int:
	if _spawned >= count:
		return 0
	if _spawned == 0:
		_spawned = 1
		_timer = 0.0
		return monster_id
	_timer += delta
	if _timer >= interval:
		_spawned += 1
		_timer -= interval
		return monster_id
	return 0

## 该配置行对应的怪物是否已全部生成完毕
func is_done() -> bool:
	return _spawned >= count

## 重置生成计数和计时器，用于波次切换时复用
func reset() -> void:
	_spawned = 0
	_timer = 0.0


## 场景退出时释放出生点引用及单场缓存。
func cleanup() -> void:
	reset()
	_spawn_points = []
	_scene_cache.clear()

## 实例化怪物场景并添加到指定父节点，返回生成的敌人实例
func spawn(parent: Node) -> Node:
	if _spawn_points.is_empty():
		return null

	var monster_config: MonsterData = GameConfig.monsters[monster_id]
	if monster_config == null:
		return null

	var source_path: String = monster_config.source
	if source_path.is_empty():
		DebugUtility.error("enemy_spawner", "怪物配置 %d 缺少Source字段" % monster_id)
		return null

	var scene: PackedScene = _load_scene(source_path)
	if scene == null:
		return null

	var enemy: Enemy = scene.instantiate() as Enemy
	enemy.setup(monster_id)

	var spawn_pos: Vector2 = _get_random_spawn_position()
	enemy.position = spawn_pos
	parent.add_child(enemy)
	return enemy

#endregion

## 加载场景资源（带缓存）
func _load_scene(path: String) -> PackedScene:
	if _scene_cache.has(path):
		return _scene_cache[path] as PackedScene
	var scene: PackedScene = load(path)
	if scene == null:
		DebugUtility.error("enemy_spawner", "无法加载场景: %s" % path)
		return null
	_scene_cache[path] = scene
	return scene

## 从生成点列表中随机选取一个位置
func _get_random_spawn_position() -> Vector2:
	var idx: int = _rng.randi() % _spawn_points.size()
	return _spawn_points[idx].global_position
