class_name EquipmentTip
extends Control
## 根据装备内容动态构建类型与属性提示。

signal layout_updated

const TYPE_LABEL_SCENE := preload("res://scene/shop/equipment_type_label.tscn")
const ATTR_LABEL_SCENE := preload("res://scene/shop/attr_label.tscn")

@export var display_config: EquipmentTipDisplayConfig
@export var content_padding: Vector2 = Vector2(24.0, 24.0)
@export var section_separation: float = 12.0

@onready var bg: NinePatchRect = $Bg
@onready var margin: MarginContainer = $Margin
@onready var content: VBoxContainer = $Margin/Content
@onready var icon: TextureRect = $Margin/Content/IconCenter/Icon
@onready var type_list: HBoxContainer = $Margin/Content/TypeList
@onready var attr_list: VBoxContainer = $Margin/Content/AttrList


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1000
	margin.add_theme_constant_override("margin_left", roundi(content_padding.x))
	margin.add_theme_constant_override("margin_right", roundi(content_padding.x))
	margin.add_theme_constant_override("margin_top", roundi(content_padding.y))
	margin.add_theme_constant_override("margin_bottom", roundi(content_padding.y))
	content.add_theme_constant_override("separation", roundi(section_separation))


func setup(equipment: Equipment, icon_size: Vector2) -> void:
	if equipment == null:
		return
	var data := GameConfig.equipment.get(equipment.id) as EquipmentData
	if data == null:
		DebugUtility.warn("EquipmentTip", "未找到装备配置: %d" % equipment.id)
		return
	_clear_list(type_list)
	_clear_list(attr_list)
	icon.texture = load(data.source) as Texture2D if not data.source.is_empty() else null
	icon.custom_minimum_size = icon_size
	icon.size = icon_size
	var type_label := TYPE_LABEL_SCENE.instantiate() as EquipmentTypeLabel
	type_list.add_child(type_label)
	type_label.setup(data.type, display_config)
	for key in data.attr:
		var attr_label := ATTR_LABEL_SCENE.instantiate() as AttrLabel
		attr_list.add_child(attr_label)
		attr_label.setup(String(key), data.attr[key], display_config)
	_resize_to_content.call_deferred()


func _resize_to_content() -> void:
	await get_tree().process_frame
	var content_minimum := content.get_combined_minimum_size()
	custom_minimum_size = content_minimum + content_padding * 2.0
	size = custom_minimum_size
	bg.size = size
	layout_updated.emit()


func _clear_list(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


static func calculate_position(
	card_rect: Rect2,
	tip_size: Vector2,
	viewport_size: Vector2,
	gap: float
) -> Vector2:
	var left_x := card_rect.position.x - gap - tip_size.x
	var right_x := card_rect.end.x + gap
	var position_x := left_x if left_x >= 0.0 else right_x
	if position_x + tip_size.x > viewport_size.x:
		position_x = left_x
	position_x = clampf(position_x, 0.0, maxf(viewport_size.x - tip_size.x, 0.0))
	var position_y := clampf(
		card_rect.position.y,
		0.0,
		maxf(viewport_size.y - tip_size.y, 0.0)
	)
	return Vector2(position_x, position_y)
