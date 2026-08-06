class_name CharacterSelect
extends Control
## 角色选择场景：展示可选角色，确认后开始游戏

@onready var card_container: CarouselContainer = $Scroller/CardContainer
@onready var container: Control = $Scroller/CardContainer/Container
@onready var deploy_button: Button = $DeployButton
@onready var _left_button: Button = $Scroller/Left
@onready var _right_button: Button = $Scroller/Right
@onready var _descript_label: Label = $Descript/CenterContainer/Label
@onready var _name_label: Label = $Name/Label
@onready var _illustration_texture: TextureRect = $Show/TextureRect

var _selected_character_id: int
@export var _card_scene: PackedScene = preload("res://scene/main/character_card.tscn")

func _ready() -> void:
	deploy_button.pressed.connect(_on_deploy_button_pressed)
	_left_button.pressed.connect(_on_left_pressed)
	_right_button.pressed.connect(_on_right_pressed)

	_populate_character_cards()
	card_container.selected_index = 0
	var select_card: CharacterCard = container.get_child(card_container.selected_index)
	_selected_character_id = select_card._character_id
	_update_nav_buttons()
	_update_character_info()

#region 内部方法

## 根据角色配置表动态创建角色卡片并加入滚动列表
func _populate_character_cards() -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

	for cid in GameConfig.characters:
		var card: CharacterCard = _card_scene.instantiate()
		container.add_child(card)
		card.setup(cid)
		card.card_selected.connect(_on_character_selected)
		

## 更新左右导航按钮的可见性
func _update_nav_buttons() -> void:
	_left_button.visible = _selected_character_id > 1
	_right_button.visible = _selected_character_id < container.get_child_count()


## 刷新角色信息
func _update_character_info() -> void:
	var char_data: CharacterData = GameConfig.characters[_selected_character_id]
	var char_name: String = char_data.name
	_name_label.text = char_name

	var char_descript: String = char_data.descript
	_descript_label.text = char_descript

	var char_illustration: String = char_data.illustration
	_illustration_texture.texture = load(char_illustration) as Texture2D

#endregion

#region 信号回调

## 角色选中回调
func _on_character_selected(id: int) -> void:
	_selected_character_id = id
	for card: CharacterCard in container.get_children():
		card.set_selected(id)
	_update_nav_buttons()
	_update_character_info()


## 向左选择角色
func _on_left_pressed() -> void:
	card_container._left()
	var card: CharacterCard = container.get_child(card_container.selected_index)
	_on_character_selected(card._character_id)


## 向右选择角色
func _on_right_pressed() -> void:
	card_container._right()
	var card: CharacterCard = container.get_child(card_container.selected_index)
	_on_character_selected(card._character_id)


## 出击按钮回调：以选中角色开始新一局
func _on_deploy_button_pressed() -> void:
	if _selected_character_id > 0:
		GameState.start_new_run(_selected_character_id)
		GameState.change_scene("gaming")

#endregion
