class_name BattleUI
extends CanvasLayer
## 战斗HUD：显示血量、金币、波次和伤害数字
@onready var _game_over: GameOver = $GameOver
@onready var _health_bar: ProgressBar = $HealthBar/ProgressBar
@onready var _gold_label: Label = $Gold/Value
@onready var _wave_label: Label = $Wave/Value
@onready var _damage_show: Control = $DamageShow

@export var DAMAGE_LABEL_SCENE: PackedScene = preload("res://scene/battle/damage_label.tscn")

func _ready() -> void:
	CombatManager.update_wave_show.connect(_on_wave_show)
	CombatManager.gold_collected.connect(_on_gold_collected)
	CombatManager.damage_dealt.connect(_on_damage_dealt)
	update_health_bar()
	_update_gold_display()

#region 公开方法

## 展示游戏结束
func show_game_over(won: bool) -> void:
	_game_over.show_game_over(won)

## 每帧从玩家节点同步血量到进度条
func update_health_bar() -> void:
	var player: Player = GameState.find_player()
	if player == null:
		return
	_health_bar.max_value = player.attrs.get_value(AttrType.Type.HP)
	_health_bar.value = player.current_hp

#endregion

#region 内部方法

## 刷新金币数量显示
func _update_gold_display() -> void:
	_gold_label.text = str(GameState.gold)


## 在指定世界坐标实例化伤害数字并播放动画
func _show_damage(damage: int, world_position: Vector2) -> void:
	var label: DamageLabel = DAMAGE_LABEL_SCENE.instantiate() as DamageLabel
	_damage_show.add_child(label)
	var viewport: Viewport = get_viewport()
	var camera: Camera2D = viewport.get_camera_2d()
	if camera:
		var viewport_center: Vector2 = viewport.get_visible_rect().size / 2.0
		label.position = (world_position - camera.global_position) / camera.zoom + viewport_center
	else:
		label.position = world_position
	label.setup(damage)

#endregion

#region 信号回调

## 波次开始回调：更新波次显示
func _on_wave_show(wave_index: int) -> void:
	_wave_label.text = str(wave_index + 1)


## 金币收集回调：刷新金币显示
func _on_gold_collected(_amount: int) -> void:
	_update_gold_display()


## 伤害处理回调：在受击目标位置显示伤害数字
func _on_damage_dealt(target: Node, amount: float) -> void:
	if target.take_damage(amount):
		_show_damage(int(amount), target.global_position)

#endregion