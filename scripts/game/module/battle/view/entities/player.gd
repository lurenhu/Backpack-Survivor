class_name Player
extends CharacterBody2D
## 玩家角色：WASD移动，属性从背包系统同步，自动战斗

@onready var body_ani: AnimatedSprite2D = $BodyAni
@onready var equipment_host: EquipmentHost = $Components/EquipmentHost
@onready var weapon_anchor: Node2D = $EquipmentEntities/WeaponAnchor
@onready var shooter_anchor: Node2D = $EquipmentEntities/ShooterAnchor
@onready var area_anchor: Node2D = $EquipmentEntities/AreaAnchor
@onready var hit_timer: Timer = $HitTimer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var dust: GPUParticles2D = $Dust


# 角色属性
## 移动阻尼值，控制加速/减速过渡速率，值越大响应越快
@export var damping: float = 800.0
var current_hp: float = 100.0
var _is_death: bool = false
var attrs: AttrContainer = null

# 角色动画
var _animate_perfix: StringName = &"idle"
var _pudding: StringName = &"pudding"
var _sprite_frame_path: String = ""

func _ready() -> void:
	add_to_group("player")
	if GameState.current_character_id > 0:
		setup(GameState.current_character_id)

	## 布丁动画播放
	if animation_player.has_animation(_pudding):
		if animation_player.current_animation != _pudding:
			animation_player.play(_pudding)

	## 序列帧动画
	if _sprite_frame_path != "":
		var frames: SpriteFrames = load(_sprite_frame_path)
		if frames:
			body_ani.sprite_frames = frames

	_update_animation()
	var equipment_context := EquipmentContext.new().setup(self, weapon_anchor, shooter_anchor, area_anchor)
	equipment_host.initialize(BackpackManager.equipments.values(), equipment_context)

func _physics_process(_delta: float) -> void:
	var move_input: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target_velocity: Vector2 = move_input * attrs.get_value(AttrType.Type.SPD)
	velocity = velocity.move_toward(target_velocity, damping * _delta)
	move_and_slide()

	_animate_perfix = &"run" if move_input != Vector2.ZERO else &"idle"

	if move_input != Vector2.ZERO:
		body_ani.flip_h = false if move_input.x > 0 else true

	_update_animation()

	dust.emitting = move_input != Vector2.ZERO

#region 动画

## 更新动画
func _update_animation():
	var animation_name: StringName = StringName("%s" % _animate_perfix)

	if not body_ani.sprite_frames.has_animation(animation_name):
		DebugUtility.error("player", "not have animation %s" % animation_name)
		return

	if body_ani.animation != animation_name or not body_ani.is_playing():
		body_ani.play(animation_name)

	if _animate_perfix == &"run":
		animation_player.speed_scale = 2.0
	else:
		animation_player.seek(0.0)

#endregion

#region 公开功能

## 根据角色ID获取配置并初始化血量、速度等属性
func setup(config_id: int) -> void:
	var char_data: CharacterData = GameConfig.characters[config_id]
	if char_data == null:
		DebugUtility.error("player", "未找到角色配置: %d" % config_id)
		return

	var attr_dic: Dictionary = char_data.attr
	attrs = AttrType.from_csv_dict(attr_dic)
	current_hp = attrs.get_value(AttrType.Type.HP)
	_is_death = false
	
	_sprite_frame_path = char_data.frame_path

## 受到伤害（仅在计时器结束时可受击，受击后开始计时）
func take_damage(amount: float) -> bool:
	if _is_death or not is_finite(amount) or amount <= 0.0 or not hit_timer.is_stopped():
		return false
	current_hp = max(current_hp - amount, 0.0)
	hit_timer.start()
	if current_hp <= 0 and not _is_death:
		_is_death = true
		CombatManager.end_battle(false)
	return true

#endregion
