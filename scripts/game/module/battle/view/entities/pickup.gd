class_name Pickup
extends Area2D
## 掉落物：金币/经验/生命拾取，支持磁铁吸附

enum PickupType {GOLD, EXP}

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var timer: Timer = $Timer

@export var type: PickupType = PickupType.GOLD
@export var value: int = 1
@export var magnet_speed: float = 400.0
@export_range(0.0, 10.0, 0.1, "or_greater") var blink_before_exprie: float = 1.2

var _attracted: bool = false
var _target: Node2D = null
var _is_expire: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	timer.timeout.connect(_on_timeout)
	if timer.wait_time > 0:
		timer.start()
	_set_blink_enable(false)

func _process(delta: float) -> void:
	if _is_expire:
		return

	## 被吸附时向目标移动
	if _attracted and _target != null:
		var direction: Vector2 = (_target.global_position - global_position).normalized()
		global_position += direction * magnet_speed * delta

	if timer.is_stopped():
		return
	if timer.time_left > blink_before_exprie:
		return
	_is_expire = true
	_set_blink_enable(true)

## 根据pickup配置初始化精灵动画和碰撞形状
func setup(config_id: int) -> void:
	var config: PickupData = GameConfig.pickups[config_id]
	if config == null:
		DebugUtility.error("pick_up_config", "is null id:%s" % config_id)
		return

	var config_type: String = config.type
	if not config_type.is_empty() and config_type in PickupType:
		type = PickupType[config_type]

	var source_path: String = config.source
	if not source_path.is_empty() and animated_sprite_2d != null:
		animated_sprite_2d.sprite_frames = load(source_path)
		animated_sprite_2d.play()

	var collision_path: String = config.collision
	if not collision_path.is_empty() and collision_shape_2d != null:
		collision_shape_2d.shape = load(collision_path)

## 设置是否闪烁
func _set_blink_enable(enable: bool) -> void:
	var sprite_material := animated_sprite_2d.material as ShaderMaterial
	if sprite_material != null:
		sprite_material.set_shader_parameter("blink_enable", enable)

## 玩家触碰时收集
func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_collect()

## 处理拾取效果：金币增加、生命回复
func _collect() -> void:
	match type:
		PickupType.GOLD:
			GameState.add_gold(value)
			CombatManager.gold_collected.emit(value)
	call_deferred("queue_free")

func _on_timeout() -> void:
	queue_free()
