extends Node2D
## 战斗场景：控制战斗流程，管理关卡计时和波次推进

@onready var _battle_ui: BattleUI = $BattleUI
@onready var _stage_timer: Timer = $StageTimer
@onready var _enemy_container: Node2D = $EnemyContainer
@onready var _pick_up_container: Node2D = $PickUpContainer
@onready var bullet_container: Node2D = $BulletContainer

var _stage_duration: float = 0.0

const BULLET_SCENE: PackedScene = preload("res://scene/battle/entities/bullet.tscn")

## 就绪时初始化战斗：读取关卡配置，设置阶段计时器，启动战斗管理器
func _ready() -> void:
	var config_id: int = MapManager.current_map_node.config_id
	var wave_data: Dictionary = GameConfig.battles[config_id]
	# 计算所有波次的总时长作为关卡阶段时长
	_stage_duration = 0.0
	for wave_id in wave_data:
		var first_config: BattleConfigData = wave_data[wave_id].values()[0]
		_stage_duration += first_config.limit
	_stage_timer.wait_time = _stage_duration
	_stage_timer.start()
	CombatManager.setup_from_config(wave_data)

	var spawn_points: Array[Marker2D] = []
	for child in $EnemySpawner.get_children():
		if child is Marker2D:
			spawn_points.append(child as Marker2D)
	CombatManager.register_spawn_points(spawn_points)
	CombatManager.register_spawn_parent(_enemy_container)
	CombatManager.register_pickup_parent(_pick_up_container)

	CombatManager.battle_ended.connect(_on_battle_ended)
	CombatManager.damage_dealt.connect(_on_damage_dealt)
	CombatManager.shoot_bullet.connect(_on_shoot_bullet)

## 每帧更新战斗计时和战斗逻辑
func _process(delta: float) -> void:
	var elapsed: float = _stage_duration - _stage_timer.time_left
	CombatManager.tick_combat(delta, elapsed)

#region 信号回调

func _on_damage_dealt(target: Node, amount: int):
	if target == null:
		return
	if amount == 0:
		return

	_battle_ui.update_health_bar()

## 战斗结束回调：失败则GameOver，最顶层通关则GameOver，否则回到地图
func _on_battle_ended(won: bool) -> void:
	_battle_ui.show_game_over(won)


## 发射子弹：朝目标方向生成num颗子弹，小角度扇形散开避免重叠
func _on_shoot_bullet(source: Node, target: Node, num: int, damage: int, speed: int, from: Node2D) -> void:
	var base_direction: Vector2 = (target.global_position - source.global_position).normalized()
	const SPREAD_ANGLE: float = PI / 24.0
	for i in num:
		var bullet: Bullet = BULLET_SCENE.instantiate()
		bullet.global_position = source.global_position
		var angle_offset: float = (i - (num - 1) * 0.5) * SPREAD_ANGLE
		var direction: Vector2 = base_direction.rotated(angle_offset)
		bullet.setup(damage, speed, direction, from)
		bullet_container.add_child(bullet)

#endregion