class_name CharacterCard
extends Control
## 角色选择卡片：显示角色idle动画、名称，点击时发出选中信号

@onready var card_select: NinePatchRect = $CardShow/CardSelect
@onready var card_sprite: AnimatedSprite2D = $CardShow/CardSprite
@onready var click: Button = $Click

signal card_selected(character_id: int)

var _character_id: int = 0

## 忽略鼠标事件让ScrollContainer能检测拖拽，通过Button的PASS模式传递事件
func _ready() -> void:
	click.pressed.connect(_on_button_pressed)

## 配置卡片：设置角色ID、名称和idle动画帧
func setup(character_id: int) -> void:
	_character_id = character_id
	var char_data: CharacterData = GameConfig.characters[_character_id]
	var animatePath: String = char_data.frame_path
	var sprite_frames: SpriteFrames = null
	if not animatePath.is_empty():
		sprite_frames = load(animatePath)
	
	if sprite_frames:
		card_sprite.sprite_frames = sprite_frames
		if sprite_frames.has_animation("sprite"):
			card_sprite.play("sprite")

## ----信号回调----

## 按钮触发选中角色卡片
func _on_button_pressed() -> void:
	grab_focus()
	card_selected.emit(_character_id)

## ----公开接口----

## 设置选中高亮状态
func set_selected(character_id: int) -> void:
	card_select.visible = _character_id == character_id
