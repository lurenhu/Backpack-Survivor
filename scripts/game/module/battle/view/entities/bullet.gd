class_name Bullet
extends Area2D
## 子弹：朝指定方向直线飞行，命中Player/Enemy造成伤害后销毁，命中World直接销毁

var _damage: int = 0
var _speed: float = 0.0
var _direction: Vector2 = Vector2.ZERO
var _from: Node2D = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += _direction * _speed * delta


## 初始化子弹属性
func setup(damage: int, speed: float, direction: Vector2, from: Node2D) -> void:
	_damage = damage
	_speed = speed
	_direction = direction
	_from = from

func _on_body_entered(body: Node2D) -> void:
	if is_instance_valid(_from):
		if _from is Player and body is Player:
			return
		if _from is Enemy and body is Enemy:
			return

	if body is Player or body is Enemy:
		if body.has_method("take_damage"):
			CombatManager.damage_dealt.emit(body, _damage)
	queue_free()
