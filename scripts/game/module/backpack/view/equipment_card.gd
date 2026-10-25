class_name EquipmentCard
extends Control
## 装备卡片：在背包网格中显示装备占用的形状格子和装备图标，支持拖拽和右键旋转
## 旋转通过控件rotation实现；equipment 是显示快照，拖拽期间不修改正式库存。

signal drag_dropped(screen_position: Vector2)
signal drag_state_changed(is_dragging: bool)

const EQUIPMENT_TIP_SCENE := preload("res://scene/shop/equipment_tip.tscn")

@onready var grid_preview: Control = $GridPreview
@onready var _grid_tile: TileMapLayer = $GridPreview/GridTile
@onready var equipment_sprite: TextureRect = $EquipmentSprite

## 绕x轴最大倾斜角度
@export var angle_x_max: float = 20.0
## 绕y轴最大倾斜角度
@export var angle_y_max: float = 20.0
## 鼠标保持悬停多久后显示装备提示。
@export_range(0.0, 10.0, 0.1) var tooltip_delay: float = 2.0
## 装备卡片与提示框之间的间隔。
@export_range(0.0, 100.0, 1.0) var tooltip_gap: float = 12.0

var equipment: Equipment = null
var origin_equipment: Equipment = null
## 商店卡牌保存商品编号；装备实例编号由 equipment.instance_id 提供。
var offer_id: int = 0

var _origin_pos: Vector2 = Vector2.ZERO

var _is_dragging: bool = false
var _is_pressed: bool = false

var _scale_tween: Tween
var _rot_tween: Tween
var _move_tween: Tween
var _rotate_tween: Tween
var _tooltip_timer: Timer
var _equipment_tip: EquipmentTip

## 就绪时设置鼠标过滤，确保控件可以接收输入事件
func _ready() -> void:
	mouse_entered.connect(_on_mouse_enter)
	mouse_exited.connect(_on_mouse_exit)
	_tooltip_timer = Timer.new()
	_tooltip_timer.one_shot = true
	_tooltip_timer.timeout.connect(_show_equipment_tip)
	add_child(_tooltip_timer)


func _exit_tree() -> void:
	_hide_equipment_tip()

## 处理鼠标输入：左键长按拖拽、右键旋转
func _gui_input(event: InputEvent) -> void:
	_handle_mouse_click(event)
	_handle_mouse_move(event)

#region 内部方法

## 处理鼠标点击事件
func _handle_mouse_click(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_pressed = true
				_on_drag_start(event.global_position)
			else:
				_is_pressed = false
				if _is_dragging:
					_on_drag_end()
				else:
					return_to_origin()
				#DebugUtility.info("card_global_position", "%s"%global_position)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed and _is_pressed:
				_on_rotate()
	elif event is InputEventMouseMotion:
		if _is_pressed:
			_on_drag_move(event.global_position)


## 处理鼠标移动事件：根据鼠标在卡片上的位置计算3D倾斜角度
func _handle_mouse_move(event: InputEvent) -> void:
	if not event is InputEventMouseMotion:
		return

	var mouse_pos: Vector2 = get_local_mouse_position()

	var lerp_val_x: float = remap(mouse_pos.x, 0.0, custom_minimum_size.x, 0, 1)
	var lerp_val_y: float = remap(mouse_pos.y, 0.0, custom_minimum_size.y, 0, 1)

	var rot_y: float = lerpf(angle_y_max, -angle_y_max, lerp_val_y)
	var rot_x: float = lerpf(-angle_x_max, angle_x_max, lerp_val_x)

	equipment_sprite.material.set_shader_parameter("x_rot", rot_y)
	equipment_sprite.material.set_shader_parameter("y_rot", rot_x)


## 记录拖拽起始位置和旋转状态，并将pivot中心吸附到鼠标位置
func _on_drag_start(mouse_global: Vector2) -> void:
	_hide_equipment_tip()
	_origin_pos = position
	if equipment:
		origin_equipment = equipment.copy()

	var parent_ofs: Vector2 = get_parent().global_position
	position = mouse_global - parent_ofs - pivot_offset
	
	z_index = 1

	grid_preview.visible = false


## 拖拽过程中让pivot中心跟随鼠标移动，首次移动超过阈值时开始拖拽
func _on_drag_move(mouse_global: Vector2) -> void:
	_is_dragging = true
	drag_state_changed.emit(true)

	var parent_ofs: Vector2 = get_parent().global_position
	position = mouse_global - parent_ofs - pivot_offset


## 拖拽结束：通过 global_position + P.rotated(rotation) 计算第一个网格中心的全局坐标
func _on_drag_end() -> void:
	_is_dragging = false
	drag_state_changed.emit(false)

	var first_pos: Vector2 = get_occupied_global_centers()[0]
	drag_dropped.emit(first_pos)

	z_index = 0

	grid_preview.visible = equipment.state == BackpackManager.GridType.SHOP


## 获取当前卡片所有占用格子的全局中心坐标，用于判断网格高亮
func get_occupied_global_centers() -> Array[Vector2]:
	var centers: Array[Vector2] = []
	if equipment == null or equipment.shape.is_empty():
		return centers

	var half_cell: float = BackpackManager.CELL_SIZE / 2.0
	var cell_center: Vector2 = Vector2(half_cell, half_cell)

	# 计算旋转中心点的全局坐标
	var pivot_global: Vector2
	match equipment.rotate_times:
		0: pivot_global = global_position + Vector2(pivot_offset.x, pivot_offset.y)
		1: pivot_global = global_position + Vector2(-pivot_offset.y, pivot_offset.x)
		2: pivot_global = global_position + Vector2(-pivot_offset.x, -pivot_offset.y)
		3: pivot_global = global_position + Vector2(pivot_offset.y, -pivot_offset.x)
		_: return centers

	# 计算最左上角网格中心的全局坐标
	var first_center: Vector2
	match equipment.rotate_times:
		0, 2: first_center = pivot_global - Vector2(pivot_offset.x, pivot_offset.y) + cell_center
		1, 3: first_center = pivot_global - Vector2(pivot_offset.y, pivot_offset.x) + cell_center
		_: return centers

	var shape: Array[Array] = equipment.shape
	var cell_size: int = BackpackManager.CELL_SIZE

	for y in shape.size():
		for x in shape[y].size():
			if shape[y][x] == 1:
				var offset: Vector2 = Vector2(x * cell_size, y * cell_size)
				centers.append(first_center + offset)

	return centers


## 拖拽中右键旋转装备：更新equipment数据并同步控件旋转角度
func _on_rotate() -> void:
	if not _is_dragging:
		_is_dragging = true
		drag_state_changed.emit(true)
	
	if equipment == null:
		return
	equipment.rotate_clockwise()

	var target_rotation = 2 * PI if equipment.rotate_times == 0 else equipment.rotate_times * PI / 2.0
	if _rotate_tween and _rotate_tween.is_valid():
		_rotate_tween.kill()
	_rotate_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	_rotate_tween.tween_property(self, "rotation", target_rotation, 0.15)
	_rotate_tween.tween_callback(func():
		rotation = equipment.rotate_times * PI / 2.0
	)


## 初始化显示
func _init_display() -> void:
	if equipment == null:
		return
	
	var equipment_data = GameConfig.equipment[equipment.id]
	var shape = equipment_data.shape
	var rows = shape.size()
	var cols = shape[0].size()
	var cell_size: int = BackpackManager.CELL_SIZE
	var base_size = Vector2(cols * cell_size, rows * cell_size)

	# 初始化大小，锚点旋转
	custom_minimum_size = base_size
	equipment_sprite.custom_minimum_size = base_size
	pivot_offset = base_size / 2.0
	rotation = equipment.rotate_times * PI / 2.0

	# 加载装备贴图
	var source_path: String = equipment_data.source
	if not source_path.is_empty():
		var texture: Texture2D = load(source_path)
		if texture != null:
			equipment_sprite.texture = texture
	
	# 根据原始形状生成瓦片，旋转通过控件rotation实现
	_grid_tile.clear()
	for y in range(rows):
		for x in range(cols):
			if shape[y][x] == 1:
				_grid_tile.set_cell(Vector2i(x, y), 1, Vector2i.ZERO)

	grid_preview.visible = equipment.state == BackpackManager.GridType.SHOP


#endregion

#region 信号回调

## 鼠标进入：tween快进缓出放大
func _on_mouse_enter() -> void:
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	_scale_tween.tween_property(self, "scale", Vector2.ONE * 1.2, 0.15)
	if equipment != null and not _is_dragging and mouse_filter != Control.MOUSE_FILTER_IGNORE:
		_tooltip_timer.start(tooltip_delay)


## 鼠标离开：tween快进缓出恢复，重置shader旋转角度
func _on_mouse_exit() -> void:
	_hide_equipment_tip()
	if _scale_tween and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	_scale_tween.tween_property(self, "scale", Vector2.ONE, 0.15)

	if _rot_tween and _rot_tween.is_valid():
		_rot_tween.kill()
	_rot_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_rot_tween.tween_property(equipment_sprite.material, "shader_parameter/x_rot", 0.0, 0.15)
	_rot_tween.tween_property(equipment_sprite.material, "shader_parameter/y_rot", 0.0, 0.15)


func _show_equipment_tip() -> void:
	if equipment == null or _is_dragging or _is_pressed:
		return
	_hide_equipment_tip()
	_equipment_tip = EQUIPMENT_TIP_SCENE.instantiate() as EquipmentTip
	_get_tooltip_parent().add_child(_equipment_tip)
	_equipment_tip.layout_updated.connect(
		_position_equipment_tip.bind(_equipment_tip),
		CONNECT_ONE_SHOT
	)
	_equipment_tip.setup(equipment, equipment_sprite.size)


func _get_tooltip_parent() -> Node:
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is CanvasLayer:
			return ancestor
		ancestor = ancestor.get_parent()
	return get_tree().root


func _position_equipment_tip(tip: EquipmentTip) -> void:
	if not is_instance_valid(tip) or tip != _equipment_tip:
		return
	var viewport_size := get_viewport_rect().size
	tip.position = EquipmentTip.calculate_position(
		get_global_rect(),
		tip.size,
		viewport_size,
		tooltip_gap
	)


func _hide_equipment_tip() -> void:
	if _tooltip_timer != null:
		_tooltip_timer.stop()
	if is_instance_valid(_equipment_tip):
		_equipment_tip.queue_free()
	_equipment_tip = null

#endregion

#region 公开方法

## 配置卡片：从DataManager读取装备数据，创建Equipment并刷新显示
func setup(equipment_id: int, state: BackpackManager.GridType = BackpackManager.GridType.SHOP) -> void:
	var config: EquipmentData = GameConfig.equipment[equipment_id]
	if config == null:
		DebugUtility.warn("equipment_card", "config is null")

	equipment = Equipment.new(equipment_id)
	equipment.state = state
	origin_equipment = equipment.copy()
	_init_display()


## 配置卡片：从DataManager读取装备数据，创建Equipment并刷新显示
func setup_by_equipment(equipment_param: Equipment) -> void:
	if equipment_param == null:
		return

	_cancel_motion()
	equipment = equipment_param.copy()
	origin_equipment = equipment.copy()
	_init_display()


## 归位：将卡片移回拖拽前的原始位置，并恢复旋转角度、形状和equipment数据
func return_to_origin() -> void:
	_cancel_motion()
	if equipment:
		equipment.copy_equipment(origin_equipment)
	rotation = equipment.rotate_times * PI / 2.0

	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	_move_tween.tween_property(self, "position", _origin_pos, 0.15)


func is_interacting() -> bool:
	return _is_pressed or _is_dragging


func finish_drag() -> void:
	_is_pressed = false
	_is_dragging = false
	_cancel_motion()


func _cancel_motion() -> void:
	if _rotate_tween and _rotate_tween.is_valid():
		_rotate_tween.kill()
	if _move_tween and _move_tween.is_valid():
		_move_tween.kill()


## 获取旋转之后本地坐标偏移量
func get_rotate_offset() -> Vector2:
	var rotate_offset: Vector2 = Vector2.ZERO
	if equipment.rotate_times % 2 == 1:
		rotate_offset = Vector2(pivot_offset.x - pivot_offset.y, pivot_offset.y - pivot_offset.x)
	# DebugUtility.info("rotate_offset", "%s, %s" % [rotate_offset])
	return rotate_offset


## 将当前装备卡片设置为预览模式
func set_preview_modulate(is_preview: bool):
	if is_preview:
		_hide_equipment_tip()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		equipment_sprite.material.set_shader_parameter("modulate", Color(0.4, 0.4, 0.4, 1.0))
	else:
		mouse_filter = Control.MOUSE_FILTER_PASS
		equipment_sprite.material.set_shader_parameter("modulate", Color.WHITE)


## 返回当前显示的装备提示，便于界面管理与验证。
func get_equipment_tip() -> EquipmentTip:
	return _equipment_tip if is_instance_valid(_equipment_tip) else null
		
#endregion
