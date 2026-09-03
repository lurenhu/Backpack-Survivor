class_name TargetingShooter
extends ShooterBase
## 锁敌发射器，在检测范围内选择距离最近的敌人进行射击。

## 用于查询范围内目标的检测区域。
var detect_area: Area2D = null
## 控制检测半径的圆形碰撞节点。
var detect_collision: CollisionShape2D = null


## 获取检测节点后调用基类初始化计时器。
func _ready() -> void:
	detect_area = get_node_or_null("DetectArea") as Area2D if detect_area == null else detect_area
	detect_collision = (
		get_node_or_null("DetectArea/CollisionShape2D") as CollisionShape2D
		if detect_collision == null
		else detect_collision
	)
	super()


## 设置锁敌检测圆的半径；传入负数时按 0 处理。
func set_detect_radius(radius: float) -> void:
	if detect_collision == null:
		return
	var circle := detect_collision.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		detect_collision.shape = circle
	circle.radius = maxf(radius, 0.0)


## 自动射击计时器超时时寻找最近敌人，找到后向目标发射。
func _on_shoot_timeout() -> void:
	if not auto_fire:
		return
	var target := _find_nearest_enemy()
	if target != null:
		fire_at(target)


## 遍历检测区域内的 Enemy，返回距离发射器最近的有效目标。
func _find_nearest_enemy() -> Enemy:
	if detect_area == null:
		return null
	var nearest: Enemy = null
	var nearest_distance := INF
	for body: Node2D in detect_area.get_overlapping_bodies():
		if not body is Enemy:
			continue
		var distance := global_position.distance_squared_to(body.global_position)
		if distance < nearest_distance:
			nearest = body
			nearest_distance = distance
	return nearest
