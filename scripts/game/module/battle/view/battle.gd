extends Node2D
## 战斗场景：控制战斗流程，管理关卡计时和波次推进

@onready var _battle_ui: BattleUI = get_node_or_null("BattleUI") as BattleUI
@onready var _stage_timer: Timer = $StageTimer
@onready var _enemy_container: Node2D = $EnemyContainer
@onready var _pick_up_container: Node2D = $PickUpContainer
## 运行时子弹实例的场景容器。
@onready var bullet_container: Node2D = $BulletContainer
## 接收发射请求并创建具体子弹的工厂节点。
@onready var _bullet_spawner: BulletSpawner = $BulletSpawner

var _stage_duration: float = 0.0

## 就绪时初始化战斗：读取关卡配置，设置阶段计时器，启动战斗管理器
func _ready() -> void:
	_bullet_spawner.setup(bullet_container)
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
	CombatManager.projectile_requested.connect(_bullet_spawner.spawn)

## 每帧更新战斗计时和战斗逻辑
func _process(delta: float) -> void:
	var elapsed: float = _stage_duration - _stage_timer.time_left
	CombatManager.tick_combat(delta, elapsed)

#region 信号回调

## 战斗结束回调：失败则GameOver，最顶层通关则GameOver，否则回到地图
func _on_battle_ended(won: bool) -> void:
	if is_instance_valid(_battle_ui):
		_battle_ui.show_game_over(won)

#endregion
