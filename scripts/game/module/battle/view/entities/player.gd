class_name Player
extends CharacterBody2D
## 玩家角色：WASD移动，属性从背包系统同步，自动战斗

@onready var body_ani: AnimatedSprite2D = $BodyAni
@onready var weapon_anchor: Node = $WeaponAnchor
@onready var shooter_anchor: Node2D = $ShooterAnchor
@onready var hit_timer: Timer = $HitTimer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var dust: GPUParticles2D = $Dust

@export var ROTATE_WEAPON_SCENE: PackedScene = preload("res://scene/battle/entities/rotate_weapon.tscn")
@export var SHOOTER_SCENE: PackedScene = preload("res://scene/battle/entities/shooter.tscn")


# 角色属性
## 移动阻尼值，控制加速/减速过渡速率，值越大响应越快
@export var damping: float = 800.0
var current_hp: float = 100.0
var _is_death: bool = false
var attrs: AttrContainer = null

# 旋转武器属性
var rotation_equipment_count: Dictionary = {}

# 发射武器属性
var shoot_equipemt_count: Dictionary = {}

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
	_initialize_weapons()

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

	animation_player.speed_scale = 2.0 if _animate_perfix == &"run" else 0.0

#endregion

#region 武器

## 实例化武器：根据背包装备生成武器实例，均匀分配旋转角度
func _initialize_weapons() -> void:
	for child in weapon_anchor.get_children():
		child.queue_free()

	var equip_list: Array[Equipment] = []
	for equip in BackpackManager.equipments.values():
		equip_list.append(equip)

	if equip_list.is_empty():
		return

	for equip: Equipment in equip_list:
		var equip_config_id = equip.id
		match equip.type:
			Equipment.EQUIPMENT_TYPE.ROTATE:
				if not rotation_equipment_count.has(equip_config_id):
					rotation_equipment_count[equip_config_id] = 1
				else:
					rotation_equipment_count[equip_config_id] += 1
			Equipment.EQUIPMENT_TYPE.SHOOTER:
				if not shoot_equipemt_count.has(equip_config_id):
					shoot_equipemt_count[equip_config_id] = 1
				else:
					shoot_equipemt_count[equip_config_id] += 1
			_: continue
	
	_init_rotation_weapon()
	_init_shooter_weapon()


## 实例化旋转装备
func _init_rotation_weapon() -> void:
	for equip_config_id in rotation_equipment_count:
		var equip_config: EquipmentData = GameConfig.equipment[equip_config_id]
		if equip_config == null:
			DebugUtility.error("equip_config", "not have configid %s" % equip_config_id)
		
		var equip_attrs: Dictionary = equip_config.attr
		var damage = float(equip_attrs.get(AttrType.get_key(AttrType.Type.ATK), 0.0))
		var rotate_radius = float(equip_attrs.get(AttrType.get_key(AttrType.Type.ROTATE_RADIUS), 0.0))
		var rotate_speed = float(equip_attrs.get(AttrType.get_key(AttrType.Type.ROTATE_SPEED), 0.0))
		var shape: Array[Array] = equip_config.shape
		var source = load(equip_config.source) as Texture2D

		var count = rotation_equipment_count[equip_config_id]
		for i in count:
			var weapon: RotateWeapon = ROTATE_WEAPON_SCENE.instantiate()
			weapon_anchor.add_child(weapon)
			weapon.setup(damage, rotate_radius, rotate_speed, shape, source)
			weapon._angle = i * TAU / count


## 实例化发射装备
func _init_shooter_weapon() -> void:
	var i = 0
	for equip_config_id in shoot_equipemt_count:
		var equip_config: EquipmentData = GameConfig.equipment[equip_config_id]
		if equip_config == null:
			DebugUtility.error("equip_config", "not have configid %s" % equip_config_id)
		
		var equip_attrs: Dictionary = equip_config.attr
		var bullet_damage = float(equip_attrs.get(AttrType.get_key(AttrType.Type.ATK), 0.0))
		var shoot_interval = float(equip_attrs.get(AttrType.get_key(AttrType.Type.SHOOT_INTERVAL), 0.0))
		var bullet_speed = float(equip_attrs.get(AttrType.get_key(AttrType.Type.BULLET_SPEED), 0.0))
		var shoot_radius = float(equip_attrs.get(AttrType.get_key(AttrType.Type.SHOOT_RADIUS), 0.0))
		var count = shoot_equipemt_count[equip_config_id]

		var shooter: Shooter = SHOOTER_SCENE.instantiate()
		shooter_anchor.add_child(shooter)
		shooter.setup(shoot_interval, bullet_speed, bullet_damage, shoot_radius, count, self)
		shooter.pos_shooter(i * TAU / count - PI / 2)
		i += 1

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
	if not hit_timer.is_stopped():
		return false
	current_hp = max(current_hp - amount, 0.0)
	hit_timer.start()
	if current_hp <= 0 and not _is_death:
		_is_death = true
		CombatManager.battle_ended.emit(false)
	return true

#endregion