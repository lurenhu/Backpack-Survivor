class_name EnemyShooter
extends Enemy
## 可远程攻击的敌人，通过动画事件驱动锁敌发射器向玩家射击。

## 敌人场景中负责生成发射请求的锁敌发射器节点。
@onready var shooter: TargetingShooter = $Shooter

## 从怪物 Attr 读取并缓存的射击参数。
@export var shoot_interval: float = 0.0
@export var shoot_count: int = 1
@export var bullet_damage: float = 0.0
@export var bullet_speed: float = 0.0
@export var detect_radius: float = 0.0

## 初始化敌人公共属性，并创建敌方普通子弹配置交给发射器。
func _ready() -> void:
	super()
	shoot_count = floori(attrs.get_value(AttrType.Type.SHOOT_NUM))
	shoot_interval = attrs.get_value(AttrType.Type.SHOOT_INTERVAL)
	bullet_speed = attrs.get_value(AttrType.Type.BULLET_SPEED)
	bullet_damage = attrs.get_value(AttrType.Type.ATK)
	var spec := ProjectileSpec.new()
	spec.bullet_type = BulletType.Type.NORMAL
	spec.direct_damage = bullet_damage
	spec.speed = bullet_speed
	spec.shot_count = maxi(shoot_count, 1)
	spec.source_faction = ProjectileSpec.Faction.ENEMY
	shooter.setup(self, spec, shoot_interval, false)
	shooter.set_detect_radius(detect_radius)

## 发射弹幕：由动画编辑器Call Method轨道触发，向玩家方向发射子弹
func fire_bullet() -> void:
	if _player == null:
		return

	var direction: Vector2 = (_player.global_position - global_position).normalized()
	if direction.x != 0:
		var offset = abs(shooter.position.x)
		shooter.position.x = offset if direction.x >= 0 else -offset
	shooter.fire_at(_player)
