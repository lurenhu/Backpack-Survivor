class_name GameConfig
extends RefCounted
## 正式配置统一由这里发布。保留字典查询接口，运行时只读，测试可用独立候选数据。

static var _snapshot := ConfigSnapshot.new()
static var _loaded: bool = false
static var _last_result: ConfigLoadResult
static var _loader := ConfigLoader.new()

static var equipment: Dictionary:
	get: return _snapshot.equipment
static var monsters: Dictionary:
	get: return _snapshot.monsters
static var characters: Dictionary:
	get: return _snapshot.characters
static var pickups: Dictionary:
	get: return _snapshot.pickups
static var shops: Dictionary:
	get: return _snapshot.shops
static var forges: Dictionary:
	get: return _snapshot.forges
static var battles: Dictionary:
	get: return _snapshot.battles
static var map_nodes: Dictionary:
	get: return _snapshot.map_nodes


static func is_ready() -> bool:
	return _loaded


static func ensure_loaded() -> bool:
	if _loaded:
		return true
	return load_configuration().success


## 启动/工具入口，不提供对局中的热更新。失败不改变已发布的任何配置。
static func load_configuration(loader: ConfigLoader = null) -> ConfigLoadResult:
	var source := loader if loader != null else _loader
	var result := source.load_all()
	_last_result = result
	if result.success:
		_snapshot = result.snapshot
		_loaded = true
	return result


static func get_diagnostics() -> String:
	return _last_result.describe() if _last_result != null else "配置尚未加载。"
