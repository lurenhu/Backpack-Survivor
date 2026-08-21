class_name EnemyShooter
extends Enemy

@onready var shooter: Shooter = $Shooter

@export var bullet_count: int = 1
@export var bullet_damage: float = 10.0
@export var bullet_speed: float = 200.0

func _ready() -> void:
	super()
	bullet_damage = attrs.get_value(AttrType.Type.ATK)
	shooter.auto_shoot = false
	shooter.setup(0.0, bullet_speed, bullet_damage, 0.0, bullet_count, self)

## 发射弹幕：由动画编辑器Call Method轨道触发，向玩家方向发射子弹
func fire_bullet() -> void:
	if _player == null:
		return

	var direction: Vector2 = (_player.global_position - global_position).normalized()
	if direction.x != 0:
		var offset = abs(shooter.position.x)
		shooter.position.x = offset if direction.x >= 0 else -offset
	shooter.shoot(_player, self)