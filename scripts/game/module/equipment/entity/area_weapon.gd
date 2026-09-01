class_name AreaWeapon
extends Node2D
## 周期性对范围内全部敌人造成伤害

const MIN_INTERVAL: float = 0.01

@onready var detect_area: Area2D = $DetectArea
@onready var collision_shape_2d: CollisionShape2D = $DetectArea/CollisionShape2D
@onready var damage_timer: Timer = $DamageTimer

var _base_attack_power: float = 0.0
var _base_area_radius: float = 0.0
var _base_area_interval: float = 0.0

var _attack_power: float = 0.0
var _area_radius: float = 0.0
var _area_interval: float = 0.0


func _ready() -> void:
	damage_timer.timeout.connect(_on_damage_timer_timeout)


func setup(attack_power: float, area_radius: float, area_interval: float) -> void:
	_base_attack_power = attack_power
	_base_area_radius = area_radius
	_base_area_interval = area_interval
	if not BackpackManager.equip_changed.is_connected(_recalculate_attributes):
		BackpackManager.equip_changed.connect(_recalculate_attributes)
	_recalculate_attributes()
	damage_timer.start()


func _equipment_attr(type: AttrType.Type) -> float:
	var attrs := BackpackManager.equipment_attrs
	return attrs.get_value(type) if attrs.has(type) else 0.0


func _recalculate_attributes() -> void:
	_attack_power = (_base_attack_power + _equipment_attr(AttrType.Type.ATK)) \
		* (1.0 + _equipment_attr(AttrType.Type.ATK_GAIN))
	_area_radius = _base_area_radius * (1.0 + _equipment_attr(AttrType.Type.AREA_RADIUS_GAIN))
	_area_interval = maxf(
		_base_area_interval * (1.0 - _equipment_attr(AttrType.Type.AREA_INTERVAL_GAIN)),
		MIN_INTERVAL
	)
	var circle_shape := collision_shape_2d.shape as CircleShape2D
	if circle_shape != null:
		circle_shape.radius = _area_radius
	damage_timer.wait_time = _area_interval
	if not damage_timer.is_stopped():
		damage_timer.start()


func _on_damage_timer_timeout() -> void:
	for body in detect_area.get_overlapping_bodies():
		if body is Enemy:
			CombatManager.damage_dealt.emit(body, _attack_power)
