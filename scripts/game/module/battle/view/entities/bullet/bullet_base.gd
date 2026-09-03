class_name BulletBase
extends Area2D
## 所有子弹行为的公共基类，负责移动、生命周期、阵营过滤和命中去重。

## 本颗子弹使用的独立属性快照。
var spec: ProjectileSpec = null
## 子弹的归一化飞行方向。
var direction: Vector2 = Vector2.ZERO
## 已命中过的目标实例 ID，用于防止同一颗子弹重复伤害同一目标。
var _hit_targets: Dictionary[int, bool] = {}
## 子弹已存活的秒数。
var _lifetime: float = 0.0
## 标记子弹正在结束，防止重复处理命中或释放。
var _finishing: bool = false


## 连接物理碰撞信号。
func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


## 按配置速度移动子弹，并在超过最长生命周期时回收。
func _physics_process(delta: float) -> void:
	if spec == null or _finishing:
		return
	global_position += direction * spec.speed * delta
	_lifetime += delta
	if _lifetime >= spec.max_lifetime:
		_finish()


## 使用生成请求初始化世界坐标、飞行方向和属性快照。
func setup(request: ProjectileSpawnRequest) -> void:
	if request == null:
		return
	global_position = request.global_position
	direction = request.direction
	spec = request.spec.snapshot() if request.spec != null else null


## 处理进入碰撞区的物体：忽略友军，将合法目标交给子类，障碍物则结束子弹。
func _on_body_entered(body: Node2D) -> void:
	if _finishing or spec == null:
		return
	if _is_friendly(body):
		return
	if _accept_hit(body):
		_on_valid_target_hit(body)
	elif not (body is Player or body is Enemy):
		_finish()


## 检查目标是否合法且尚未命中；接受命中时记录目标实例 ID。
func _accept_hit(body: Node2D) -> bool:
	if not _is_valid_target(body):
		return false
	var target_id := body.get_instance_id()
	if _hit_targets.has(target_id):
		return false
	_hit_targets[target_id] = true
	return true


## 根据子弹阵营判断碰撞物是否为可伤害目标。
func _is_valid_target(body: Node2D) -> bool:
	if spec.source_faction == ProjectileSpec.Faction.PLAYER:
		return body is Enemy
	return body is Player


## 根据子弹阵营判断碰撞物是否为友军。
func _is_friendly(body: Node2D) -> bool:
	if spec.source_faction == ProjectileSpec.Faction.PLAYER:
		return body is Player
	return body is Enemy


## 合法目标命中钩子，由普通、穿透和爆炸子弹分别实现。
func _on_valid_target_hit(_body: Node2D) -> void:
	pass


## 通过 CombatManager 发送伤害事件，非正数伤害不会发送。
func _deal_damage(body: Node2D, amount: float) -> void:
	if amount > 0.0:
		CombatManager.damage_dealt.emit(body, amount)


## 幂等地标记子弹结束并安排释放节点。
func _finish() -> void:
	if _finishing:
		return
	_finishing = true
	queue_free()
