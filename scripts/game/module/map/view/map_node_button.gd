class_name MapNodeButton
extends Control
## 地图节点按钮：单个地图节点，处理悬停和点击交互

signal selection_requested(map_button: MapNodeButton)

@onready var bg_texture: TextureRect = $BgTexture
@onready var icon_texture: TextureRect = $IconTexture
@onready var button: Button = $Button

@export var map_id: int = 0
@export var layer: int = 0
@export var index: int = 0

var node: MapNode

var _scale_tween: Tween
var _rot_tween: Tween

## 绕x轴最大倾斜角度
@export var angle_x_max: float = 20.0
## 绕y轴最大倾斜角度
@export var angle_y_max: float = 20.0

func _ready() -> void:
	button.pressed.connect(_on_visite)
	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exit)

	bg_texture.material = bg_texture.material.duplicate()
	icon_texture.material = icon_texture.material.duplicate()

	_setup()


## 处理鼠标输入：左键长按拖拽、右键旋转
func _gui_input(event: InputEvent) -> void:
	_handle_mouse_move(event)


#region 公开功能

## 更新地图节点状态
func update_map_node():
	_check_visited()

	icon_texture.material.set_shader_parameter("x_rot", 0.0)
	icon_texture.material.set_shader_parameter("y_rot", 0.0)
	bg_texture.material.set_shader_parameter("progress", 0.0)


#endregion

#region 内部方法

## 初始化
func _setup():
	node = MapManager.find_map_node(map_id, layer, index)
	if node == null:
		button.disabled = true
		return

	match node.node_type:
		"shop": icon_texture.texture = MapManager.SHOP_TEXTURE
		"battle": icon_texture.texture = MapManager.BATTLE_TEXTURE
		"forge": icon_texture.texture = MapManager.FORGE_TEXTURE
		_: pass

	_check_visited()

## 判断当前地图节点是否已探索
func _check_visited():
	if node == null:
		button.disabled = true
		return
	if not node.visited:
		icon_texture.material.set_shader_parameter("modulate", Color.WHITE)
		button.disabled = not MapManager.is_node_reachable(node)
	else:
		icon_texture.material.set_shader_parameter("modulate", Color(0.4, 0.4, 0.4, 1.0))
		button.disabled = true

#endregion

#region 信号回调

## 地图统一协调点击动画，避免多个节点同时提交进入请求。
func _on_visite() -> void:
	selection_requested.emit(self)


func play_selection_animation() -> void:
	button.disabled = true
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tween.tween_property(bg_texture.material, "shader_parameter/progress", 1.0, 0.5)
	await tween.finished


## 处理鼠标移动事件：根据鼠标在卡片上的位置计算3D倾斜角度
func _handle_mouse_move(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return

	var mouse_pos: Vector2 = get_local_mouse_position()

	var lerp_val_x: float = remap(mouse_pos.x, 0.0, custom_minimum_size.x, 0, 1)
	var lerp_val_y: float = remap(mouse_pos.y, 0.0, custom_minimum_size.y, 0, 1)

	var rot_y: float = lerpf(angle_y_max, -angle_y_max, lerp_val_y)
	var rot_x: float = lerpf(-angle_x_max, angle_x_max, lerp_val_x)

	icon_texture.material.set_shader_parameter("x_rot", rot_y)
	icon_texture.material.set_shader_parameter("y_rot", rot_x)


## 鼠标进入：tween快进缓出放大
func _on_mouse_enter() -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	_scale_tween.tween_property(self, "scale", Vector2.ONE * 1.2, 0.15)


## 鼠标离开：tween快进缓出恢复，重置shader旋转角度
func _on_mouse_exit() -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	_scale_tween.tween_property(self, "scale", Vector2.ONE, 0.15)

	if _rot_tween and _rot_tween.is_valid():
		_rot_tween.kill()
	_rot_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_rot_tween.tween_property(icon_texture.material, "shader_parameter/x_rot", 0.0, 0.15)
	_rot_tween.tween_property(icon_texture.material, "shader_parameter/y_rot", 0.0, 0.15)


#endregion
