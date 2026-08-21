class_name RotateWeapon
extends Area2D
## 武器：围绕父级锚点做圆形旋转，通过信号暴露碰撞接口

const ROTATION_OFFSET: float = PI / 2 ## 旋转角度偏移（使武器朝外）

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

var _rotation_radius: float = 86.0 ## 旋转半径
var _rotation_speed: float = 3.0 ## 旋转速度（弧度/秒）
var _attack_power: float = 0.0
var _base_attack_power: float = 0.0
var _base_rotation_speed: float = 3.0

var _angle: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_angle += _rotation_speed * delta
	if _angle > TAU:
		_angle -= TAU
	position = Vector2(cos(_angle), sin(_angle)) * _rotation_radius
	rotation = _angle + ROTATION_OFFSET

## 设置武器基础属性
func setup(
	base_damage: float,
	rotate_radius: float,
	base_rotate_speed: float,
	shape: Array[Array],
	texture: Texture2D
) -> void:
	_base_attack_power = base_damage
	_rotation_radius = rotate_radius
	_base_rotation_speed = base_rotate_speed
	if not BackpackManager.equip_changed.is_connected(_refresh_equipment_attributes):
		BackpackManager.equip_changed.connect(_refresh_equipment_attributes)
	_refresh_equipment_attributes()
	var capsule_shape: CapsuleShape2D = collision_shape_2d.shape
	capsule_shape.radius = shape[0].size() / 2.0 * BackpackManager.CELL_SIZE
	capsule_shape.height = float(shape.size()) * BackpackManager.CELL_SIZE
	sprite_2d.texture = texture


func _equipment_attr(type: AttrType.Type) -> float:
	var attrs := BackpackManager.equipment_attrs
	return attrs.get_value(type) if attrs.has(type) else 0.0


func _refresh_equipment_attributes() -> void:
	_attack_power = (_base_attack_power + _equipment_attr(AttrType.Type.ATK)) \
		* (1.0 + _equipment_attr(AttrType.Type.ATK_PER))
	_rotation_speed = (_base_rotation_speed + _equipment_attr(AttrType.Type.ROTATE_SPEED)) \
		* (1.0 + _equipment_attr(AttrType.Type.ROTATE_SPEED_PER))

## 敌人进入武器区域 → 对敌人造成攻击力伤害并发射伤害信号
func _on_body_entered(body: Node2D) -> void:
	if body is Enemy:
		CombatManager.damage_dealt.emit(body, _attack_power)
