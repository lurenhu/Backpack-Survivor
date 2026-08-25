class_name EnemyShooter
extends Enemy

@onready var shooter: Shooter = $Shooter

@export var shoot_interval: float = 0.0
@export var shoot_count: int = 1
@export var bullet_damage: float = 0.0
@export var bullet_speed: float = 0.0
@export var detect_radius: float = 0.0

func _ready() -> void:
	super()
	shoot_count = floori(attrs.get_value(AttrType.Type.SHOOT_NUM))
	shoot_interval = attrs.get_value(AttrType.Type.SHOOT_INTERVAL)
	bullet_speed = attrs.get_value(AttrType.Type.BULLET_SPEED)
	bullet_damage = attrs.get_value(AttrType.Type.ATK)
	shooter.setup(self, shoot_interval, shoot_count, bullet_speed, bullet_damage, detect_radius)

## 发射弹幕：由动画编辑器Call Method轨道触发，向玩家方向发射子弹
func fire_bullet() -> void:
	if _player == null:
		return

	var direction: Vector2 = (_player.global_position - global_position).normalized()
	if direction.x != 0:
		var offset = abs(shooter.position.x)
		shooter.position.x = offset if direction.x >= 0 else -offset
	shooter.shoot(_player, self)