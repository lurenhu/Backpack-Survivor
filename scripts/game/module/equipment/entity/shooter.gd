class_name Shooter
extends Node2D

const DISTANCE: float = 100

@onready var detect_area: Area2D = $DetectArea
@onready var collision_shape_2d: CollisionShape2D = $DetectArea/CollisionShape2D
@onready var shoot_timer: Timer = $ShootTimer

@onready var auto_shoot: bool = true

# 基础属性
var _source: Node = null
var _base_shoot_interval: float = 0.0
var _base_shoot_count: int = 0
var _base_bullet_speed: float = 0
var _base_bullet_damage: float = 0
var _base_detect_radius: float = 0

# 最终属性
var _shoot_interval: float = 0.0
var _shoot_count: int = 0
var _bullet_speed: float = 0
var _bullet_damage: float = 0
var _detect_radius: float = 0

func _ready() -> void:
	shoot_timer.timeout.connect(_on_shoot)
	detect_area.body_entered.connect(_on_detect_area_enter)
	shoot_timer.start()


#region 公开方法

## 发射源，发射时间间隔，发射子弹数量，发射子弹速度，发射子弹伤害，检测半径
func setup(source: Node,
	shoot_interval: float,
	shoot_count: int,
	bullet_speed: float,
	bullet_damage: float,
	detect_radius: float, ) -> void:
	_base_shoot_interval = shoot_interval
	_base_shoot_count = shoot_count
	_base_bullet_speed = bullet_speed
	_base_bullet_damage = bullet_damage
	_base_detect_radius = detect_radius

	## 若发射源是玩家则根据背包装备属性加成重算数值
	if source is Player:
		BackpackManager.equip_changed.connect(_recalculate_attribute)
	_recalculate_attribute()

	## 启动时间计时器
	if _base_shoot_interval > 0.0:
		shoot_timer.wait_time = _shoot_interval
		shoot_timer.start()
	else:
		shoot_timer.stop()


func shoot(target: Node2D, from: Node2D):
	CombatManager.shoot_bullet.emit(self, target, _shoot_count, _bullet_damage, _bullet_speed, from)


## 布置射击点位
func pos_shooter(angle: float) -> void:
	position = Vector2(cos(angle), sin(angle)) * DISTANCE

#endregion

#region 私有方法

## 获取装备属性
func _equipment_attr(type: AttrType.Type) -> float:
	var attrs := BackpackManager.equipment_attrs
	return attrs.get_value(type) if attrs.has(type) else 0.0


## 计算装备数值
func _recalculate_attribute() -> void:
	if _source is Player:
		_bullet_damage = (_base_bullet_damage + _equipment_attr(AttrType.Type.ATK)) \
			* (1.0 + _equipment_attr(AttrType.Type.ATK_GAIN))
		_bullet_speed = (_base_bullet_speed + _equipment_attr(AttrType.Type.BULLET_SPEED_INC)) \
			* (1.0 + _equipment_attr(AttrType.Type.BULLET_SPEED_GAIN))
		_shoot_interval = _base_shoot_interval * (1.0 - _equipment_attr(AttrType.Type.SHOOT_INTERVAL))
		_shoot_count = _base_shoot_count
		_detect_radius = _base_detect_radius * (1.0 + _equipment_attr(AttrType.Type.SHOOT_RADIUS_GAIN))
	else:
		_bullet_damage = _base_bullet_damage
		_bullet_speed = _base_bullet_speed
		_shoot_interval = _base_shoot_interval
		_shoot_count = _base_shoot_count
		_detect_radius = _base_detect_radius
	collision_shape_2d.shape.radius = _detect_radius


## 在检测区域内查找最近的敌人
func _find_nearest_enemy() -> Enemy:
	var nearest_enemy: Enemy = null
	var nearest_dist: float = INF
	for body in detect_area.get_overlapping_bodies():
		if body is Enemy:
			var dist: float = global_position.distance_squared_to(body.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_enemy = body
	return nearest_enemy

#endregion

#region 信号回调

## 射击计时器归零时：检测最近敌人，发射子弹
func _on_shoot() -> void:
	if not auto_shoot:
		return

	if not _source is Player:
		return

	var nearest_enemy: Enemy = _find_nearest_enemy()
	if nearest_enemy == null:
		return
		
	shoot(nearest_enemy, _source)
	shoot_timer.start()


## 敌人进入检测范围且计时器就绪时：立即发射子弹
func _on_detect_area_enter(body: Node2D) -> void:
	if not auto_shoot:
		return

	if not body is Enemy:
		return
	if not shoot_timer.is_stopped():
		return
	shoot(body, _source)
	shoot_timer.start()

#endregion
