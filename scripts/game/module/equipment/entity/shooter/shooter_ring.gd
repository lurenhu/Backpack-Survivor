class_name ShooterRing
extends Node2D
## 管理同一种装备生成的全部发射器，并将它们均匀排列在同一圆环上。

## 三种发射器类型对应的场景资源。
const RADIAL_SCENE: PackedScene = preload(
	"res://scene/battle/entities/shooter/radial_shooter.tscn"
)
const ROTATING_RADIAL_SCENE: PackedScene = preload(
	"res://scene/battle/entities/shooter/rotating_radial_shooter.tscn"
)
const TARGETING_SCENE: PackedScene = preload(
	"res://scene/battle/entities/shooter/targeting_shooter.tscn"
)

## 所属装备 ID，用于在协调器中稳定计算圆环层序。
var equipment_id: int = 0
## 当前圆环使用的发射器类型。
var shooter_type: ShooterType.Type = ShooterType.Type.TARGETING
## 发射器相对角色中心的排列半径。
var ring_radius: float = 0.0
## 旋转径向圆环的角速度，单位为弧度/秒。
var rotate_speed: float = 0.0
## 圆环布局的初始角度偏移。
var initial_angle_offset: float = 0.0
## 发射器所属角色。
var source: Node2D = null
## 当前圆环持有的发射器实例。
var _shooters: Array[ShooterBase] = []


## 仅旋转径向类型会随时间推进整个圆环的旋转角度。
func _process(delta: float) -> void:
	if shooter_type == ShooterType.Type.ROTATING_RADIAL:
		advance_rotation(delta)


## 根据装备类型和数量重建发射器，并应用射击与检测参数。
func setup(
	new_equipment_id: int,
	new_shooter_type: ShooterType.Type,
	count: int,
	spec: ProjectileSpec,
	fire_interval: float,
	detect_radius: float,
	new_rotate_speed: float
) -> void:
	equipment_id = new_equipment_id
	shooter_type = new_shooter_type
	rotate_speed = new_rotate_speed
	if source == null:
		source = get_parent() as Node2D
	_clear_shooters()
	var scene := _scene_for_type(shooter_type)
	if scene == null:
		return
	for index in maxi(count, 0):
		var shooter := scene.instantiate() as ShooterBase
		if shooter == null:
			continue
		add_child(shooter)
		shooter.setup(source, spec, fire_interval)
		if shooter is TargetingShooter:
			(shooter as TargetingShooter).set_detect_radius(detect_radius)
		_shooters.append(shooter)
	_layout_shooters()


## 更新圆环半径并立即重新排列全部发射器。
func set_ring_radius(value: float) -> void:
	ring_radius = maxf(value, 0.0)
	_layout_shooters()


## 装备属性变化后刷新所有现有发射器，不重新创建节点。
func refresh(
	new_spec: ProjectileSpec,
	new_fire_interval: float,
	detect_radius: float,
	new_rotate_speed: float
) -> void:
	rotate_speed = new_rotate_speed
	for shooter in _shooters:
		shooter.refresh(new_spec, new_fire_interval)
		if shooter is TargetingShooter:
			(shooter as TargetingShooter).set_detect_radius(detect_radius)


## 返回当前圆环中的发射器实例列表，供协调器和测试查询。
func get_shooters() -> Array[ShooterBase]:
	return _shooters


## 按角速度推进圆环旋转，带动所有径向发射器共同转动。
func advance_rotation(delta: float) -> void:
	rotation += rotate_speed * delta


## 按相等角度间隔将发射器排列在当前半径的圆周上。
func _layout_shooters() -> void:
	if _shooters.is_empty():
		return
	for index in _shooters.size():
		var angle := initial_angle_offset + index * TAU / _shooters.size()
		_shooters[index].position = Vector2.from_angle(angle) * ring_radius


## 释放旧发射器实例并清空内部列表，为重建圆环做准备。
func _clear_shooters() -> void:
	for shooter in _shooters:
		if is_instance_valid(shooter):
			shooter.queue_free()
	_shooters.clear()


## 返回指定发射器类型对应的场景；未知类型返回 null。
func _scene_for_type(type: ShooterType.Type) -> PackedScene:
	match type:
		ShooterType.Type.RADIAL:
			return RADIAL_SCENE
		ShooterType.Type.ROTATING_RADIAL:
			return ROTATING_RADIAL_SCENE
		ShooterType.Type.TARGETING:
			return TARGETING_SCENE
		_:
			return null
