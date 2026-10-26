class_name GameOver
extends Control
## 游戏结算场景：展示本局数据统计

@onready var result_lab: Label = $ResultLab
@onready var value_lab: Label = $Score/VBoxContainer/ValueLab
@onready var continue_button: Button = $Button/VBoxContainer/ContinueButton
@onready var main_menu_button: Button = $Button/VBoxContainer/MainMenuButton
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var _settlement: RunSettlement


func _ready() -> void:
	main_menu_button.pressed.connect(_on_main_menu_button_pressed)
	continue_button.pressed.connect(_on_continue_button_pressed)


func show_game_over(settlement: RunSettlement) -> void:
	if settlement == null:
		return
	_settlement = settlement.snapshot()
	show()
	update_score()
	update_text()
	animation_player.play("show")


func update_score() -> void:
	value_lab.text = str(_settlement.collected_gold)


func update_text() -> void:
	result_lab.text = "Victory" if _settlement.won else "GameOver"
	continue_button.visible = _settlement.next_action != RunSettlement.Action.END_RUN
	match _settlement.next_action:
		RunSettlement.Action.RETRY: continue_button.text = "再来一次"
		RunSettlement.Action.NEXT_MAP: continue_button.text = "下一张图"
		RunSettlement.Action.RETURN_TO_MAP: continue_button.text = "返回地图"


func _on_main_menu_button_pressed() -> void:
	GameState.return_to_menu()


func _on_continue_button_pressed() -> void:
	if _settlement == null:
		return
	if _settlement.next_action == RunSettlement.Action.RETRY:
		GameState.retry_run(_settlement.settlement_id)
	else:
		GameState.continue_run(_settlement.settlement_id)
