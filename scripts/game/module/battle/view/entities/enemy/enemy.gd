class_name Enemy
extends CharacterBody2D
## 敌人角色：自动追踪玩家，检测范围内播放攻击动画，伤害区域对玩家造成伤害

# 怪物属性（由EnemySpawner设置）
var gold_reward: int = 1
var attrs: AttrContainer = null
@export var current_hp: float = 100.0:
	set(v):
		current_hp = v
		if current_hp <= 0:
			_die()

# 内部状态
enum EnemyState {CHASE, ATTACK}
var _state: EnemyState = EnemyState.CHASE
var _player: Player = null
var _wants_to_chase: bool = false
var _is_dead: bool = false

# 节点引用
@onready var body_sprite: AnimatedSprite2D = $BodySprite
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var detect_area: Area2D = $DetectArea
@onready var damage_area: Area2D = $DamageArea
@onready var damage_collision: CollisionShape2D = $DamageArea/CollisionShape2D
@onready var hit_timer: Timer = $HitTimer

## 就绪时查找玩家、连接信号、进入追逐状态
func _ready() -> void:
	_player = GameState.find_player()

	detect_area.body_entered.connect(_on_detect_area_body_entered)
	detect_area.body_exited.connect(_on_detect_area_body_exited)
	damage_area.body_entered.connect(_on_damage_area_body_entered)
	animation_player.animation_finished.connect(_on_animation_finished)

	_enter_chase_state()

## 追逐状态下持续向玩家移动
func _physics_process(_delta: float) -> void:
	if _player == null:
		return

	if _state == EnemyState.CHASE:
		_chase_player()
	
	_update_z_index()

#region 内部方法

## 进入追逐状态：停止攻击动画，禁用伤害碰撞，播放run动画
func _enter_chase_state() -> void:
	_state = EnemyState.CHASE
	animation_player.stop()
	damage_collision.disabled = true
	body_sprite.play("run")

## 进入攻击状态：停止移动，播放攻击动画
func _enter_attack_state() -> void:
	_state = EnemyState.ATTACK
	velocity = Vector2.ZERO
	animation_player.play("attack")

## 追逐玩家：计算方向，设置速度，根据朝向翻转精灵
func _chase_player() -> void:
	var direction: Vector2 = (_player.global_position - global_position).normalized()
	velocity = direction * attrs.get_value(AttrType.Type.SPD)

	if direction.x != 0:
		body_sprite.flip_h = direction.x < 0

	move_and_slide()

## 死亡：通知CombatManager并移除自身
func _die() -> void:
	if _is_dead:
		return
	_is_dead = true
	CombatManager.enemy_killed.emit(self, gold_reward)
	call_deferred("queue_free")

## 更新z_index
func _update_z_index():
	if _player == null:
		return

	if _player.global_position.y > global_position.y:
		z_index = _player.z_index - 1
	else:
		z_index = _player.z_index + 1

#endregion

#region 信号回调

## 玩家进入检测范围 → 取消待切换标记，切换攻击状态
func _on_detect_area_body_entered(body: Node2D) -> void:
	if body is Player:
		_wants_to_chase = false
		_enter_attack_state()

## 玩家离开检测范围 → 标记待切换，等待攻击动画播放完毕
func _on_detect_area_body_exited(body: Node2D) -> void:
	if body is Player:
		_wants_to_chase = true

## 攻击动画播放完毕 → 若玩家已离开检测范围则切换追逐，否则继续播放攻击动画
func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name != &"attack":
		return

	if _wants_to_chase:
		_enter_chase_state()
	else:
		animation_player.play("attack")

## 玩家进入伤害区域 → 对玩家造成伤害
func _on_damage_area_body_entered(body: Node2D) -> void:
	if body is Player:
		CombatManager.apply_damage(DamageRequest.create(self, body, attrs.get_value(AttrType.Type.ATK)))

#endregion

#region 公开功能

## 根据怪物ID获取配置并初始化血量、速度、攻击力等属性
func setup(config_id: int) -> void:
	var monster_config: MonsterData = GameConfig.monsters[config_id]
	if monster_config == null:
		DebugUtility.error("enemy", "未找到怪物配置: %d" % config_id)
		return

	var attrs_dic: Dictionary = monster_config.attr
	attrs = AttrType.from_csv_dict(attrs_dic)
	current_hp = attrs.get_value(AttrType.Type.HP)
	gold_reward = monster_config.gold_drop

## 受到伤害；已死亡的敌人拒绝重复命中。
func take_damage(amount: float) -> bool:
	if _is_dead or not is_finite(amount) or amount <= 0.0:
		return false
	current_hp = maxf(current_hp - amount, 0.0)
	return true

#endregion
