extends Control

@onready var start_button: Button = $NinePatchRect/VBoxContainer/StartButton
@onready var setting_button: Button = $NinePatchRect/VBoxContainer/SettingButton
@onready var exit_button: Button = $NinePatchRect/VBoxContainer/ExitButton

func _ready() -> void:
	var fade_in_first_scene_options = SceneManager.create_options(1, "fade")
	var first_scene_general_options = SceneManager.create_general_options(Color(0, 0, 0), 1, false)
	SceneManager.show_first_scene(fade_in_first_scene_options, first_scene_general_options)

	start_button.pressed.connect(_on_start_button_pressed)

## 开始按钮回调：进入角色选择
func _on_start_button_pressed() -> void:
	GameState.change_scene("character_select")
