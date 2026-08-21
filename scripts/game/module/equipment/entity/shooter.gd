class_name Shooter
extends Node2D

const DISTANCE: float = 100

@onready var detect_area: Area2D = $DetectArea
@onready var collision_shape_2d: CollisionShape2D = $DetectArea/CollisionShape2D
@onready var shoot_timer: Timer = $ShootTimer

@onready var auto_shoot: bool = true

var _shoot_num: int = 0
var _bullet_damage: float = 0
var _base_bullet_damage: float = 0
var _bullet_speed: float = 0
var _shoot_interval: float = 0.0
var _from: Node2D = null
var _attribute_container: AttributeContainer

func _ready() -> void:
	shoot_timer.timeout.connect(_on_shoot)
	detect_area.body_entered.connect(_on_detect_area_enter)
	shoot_timer.start()


## ----公开方法----

func setup(shoot_interval: float,
	bullet_speed: float,
	base_damage: float,
	radius: float,
	count: int,
	from: Node2D,
	attributes: AttributeContainer = null) -> void:
	_shoot_interval = shoot_interval
	_bullet_speed = bullet_speed
	_base_bullet_damage = base_damage
	collision_shape_2d.shape.radius = radius
	_shoot_num = count
	_from = from
	_attribute_container = attributes
	if _attribute_container != null:
		_attribute_container.attribute_changed.connect(_on_attribute_changed)
	_recalculate_bullet_damage()
	if _shoot_interval > 0.0:
		shoot_timer.wait_time = _shoot_interval
		shoot_timer.start()
	else:
		shoot_timer.stop()


func shoot(target: Node2D, from: Node2D):
	CombatManager.shoot_bullet.emit(self, target, _shoot_num, _bullet_damage, _bullet_speed, from)


## 布置射击点位
func pos_shooter(angle: float) -> void:
	position = Vector2(cos(angle), sin(angle)) * DISTANCE

## ----信号回调----

func _on_attribute_changed(type: AttrType.Type) -> void:
	if type == AttrType.Type.ATK or type == AttrType.Type.ATK_PER:
		_recalculate_bullet_damage()


func _recalculate_bullet_damage() -> void:
	_bullet_damage = _base_bullet_damage
	if _attribute_container != null:
		_bullet_damage = _attribute_container.calculate(
			_base_bullet_damage,
			AttrType.Type.ATK,
			AttrType.Type.ATK_PER
		)

## 射击计时器归零时：检测最近敌人，发射子弹
func _on_shoot() -> void:
	if not auto_shoot:
		return

	var nearest_enemy: Enemy = _find_nearest_enemy()
	if nearest_enemy == null:
		return
		
	shoot(nearest_enemy, _from)
	shoot_timer.start()


## 敌人进入检测范围且计时器就绪时：立即发射子弹
func _on_detect_area_enter(body: Node2D) -> void:
	if not auto_shoot:
		return

	if not body is Enemy:
		return
	if not shoot_timer.is_stopped():
		return
	shoot(body, _from)
	shoot_timer.start()


## ----私有方法----

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
