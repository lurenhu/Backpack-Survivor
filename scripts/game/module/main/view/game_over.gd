class_name GameOver
extends Control
## 游戏结算场景：展示本局数据统计

@onready var result_lab: Label = $ResultLab
@onready var value_lab: Label = $Score/VBoxContainer/ValueLab
@onready var continue_button: Button = $Button/VBoxContainer/ContinueButton
@onready var main_menu_button: Button = $Button/VBoxContainer/MainMenuButton
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _won: bool


func _ready() -> void:
	main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	continue_button.pressed.connect(_on_continue_button_pressed)

#region 公开方法

## 播放结算面板从屏幕上方滑落至中央的入场动画
func show_game_over(won: bool) -> void:
	_won = won
	self.show()
	update_score()
	update_text(won)
	animation_player.play("show")


func update_score() -> void:
	var score: float = GameState.total_gold_collected
	value_lab.text = str(score)


func update_text(won: bool) -> void:
	if not won:
		result_lab.text = "GameOver"
		continue_button.text = "再来一次"
	else:
		if MapManager.is_map_final_node():
			if MapManager.check_and_init_next_map():
				result_lab.text = "Victory"
				continue_button.text = "下一张图"
			else:
				result_lab.text = "Victory"
				continue_button.visible = false
		else:
			result_lab.text = "Victory"
			continue_button.text = "返回地图"

#endregion

#region 信号回调

## 返回主菜单回调
func _on_main_menu_button_pressed() -> void:
	GameState.change_scene("main_menu")

## 再来一局回调：使用相同角色重新开始
func _on_continue_button_pressed() -> void:
	if not _won:
		GameState.start_new_run(GameState.current_character_id)
	GameState.change_scene("gaming")

#endregion
