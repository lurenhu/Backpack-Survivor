class_name CharacterCard
extends Control
## 角色选择卡片：显示角色头像，点击时发出选中信号

@onready var card_select: TextureRect = $CardShow/CardSelect
@onready var card_icon: TextureRect = $CardShow/CardIcon

var _character_id: int = 0

## 配置卡片：设置角色ID和头像
func setup(character_id: int) -> void:
	_character_id = character_id
	var char_data: CharacterData = GameConfig.characters[_character_id]
	card_icon.texture = load(char_data.icon_path) as Texture2D

#region ----公开接口----

## 设置选中高亮状态
func set_selected(character_id: int) -> void:
	card_select.visible = _character_id == character_id

#endregion