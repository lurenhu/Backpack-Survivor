class_name Map
extends Control
## 地图场景脚本：加载地图数据，绘制节点和连线，处理选择交互

@onready var content: Control = $Content
@onready var bg: TextureRect = $Content/Bg
@onready var map_node_container: Control = $Content/MapNodeContainer
@onready var line_container: Control = $Content/LineContainer

var map_node_buttons: Array[MapNodeButton] = []

var _dragging: bool = false
var _drag_start_mouse_y: float = 0.0
var _drag_start_content_y: float = 0.0
var _scroll_tween: Tween = null
var _selecting_node: bool = false

func _ready() -> void:
	_setup()
	update_map_nodes()


func _gui_input(event: InputEvent) -> void:
	_handle_drag_input(event)

#region 公开方法

## 更新地图节点状态
func update_map_nodes():
	for button in map_node_buttons:
		button.update_map_node()


## 滚动到当前地图节点位置
func scroll_to_current_map_node_button():
	var cur_node = MapManager.current_map_node
	if cur_node == null:
		scroll_to_buttle()
		return
	var cur_node_button: MapNodeButton = _find_button(cur_node.layer_index, cur_node.node_index)
	if cur_node_button == null:
		return
	_scroll_content_by_tween(-cur_node_button.position.y - cur_node_button.size.y + size.y)


## 滚动到顶部
func scroll_to_top():
	_scroll_content_by_tween(0.0)


## 滚动到底部
func scroll_to_buttle():
	var min_y: float = size.y - bg.size.y
	_scroll_content_by_tween(min_y)

#endregion

#region 私有方法

## 初始化
func _setup():
	if map_node_container.get_child_count() == 0:
		_build_default_layout()
	for child: MapNodeButton in map_node_container.get_children():
		map_node_buttons.append(child)
		child.selection_requested.connect(_on_selection_requested)
	_connect_map_node_with_line()


## 动画完成后才提交业务请求；动画期间不改变访问状态，也不接受其他选点。
func _on_selection_requested(map_button: MapNodeButton) -> void:
	if _selecting_node or not is_visible_in_tree() or GameState.is_busy() or GameState.phase != RunState.Phase.MAP:
		return
	var target := map_button.node
	if not MapManager.is_node_reachable(target):
		return
	_selecting_node = true
	var source_run_id := GameState.run_id
	var source_node := MapManager.current_map_node
	await map_button.play_selection_animation()
	_selecting_node = false
	# 延迟期间可能退出地图或开始新局，旧动画不能推进新的流程。
	if not is_instance_valid(map_button):
		return
	if not is_visible_in_tree() or GameState.run_id != source_run_id or MapManager.current_map_node != source_node:
		update_map_nodes()
		return
	if MapManager.find_map_node(target.map_id, target.layer_index, target.node_index) != target:
		update_map_nodes()
		return
	if not GameState.enter_map_node(target.map_id, target.layer_index, target.node_index):
		update_map_nodes()


## 未提供手工布局的新地图按层生成，沿用已有节点和连线场景。
func _build_default_layout() -> void:
	var scene := preload("res://scene/map/map_node_button.tscn")
	var height := maxf(bg.size.y, (MapManager.get_max_layer() + 1) * 240.0)
	bg.size.y = height
	for layer in range(MapManager.get_max_layer() + 1):
		var nodes := MapManager.get_layer_nodes(layer)
		for i in nodes.size():
			var node := nodes[i]
			var button := scene.instantiate() as MapNodeButton
			button.map_id = node.map_id
			button.layer = node.layer_index
			button.index = node.node_index
			button.position = Vector2((i + 1.0) * size.x / (nodes.size() + 1.0) - 64.0, height - 200.0 - layer * 240.0)
			map_node_container.add_child(button)

## 给地图节点连接线条
func _connect_map_node_with_line():
	for button in map_node_buttons:
		var node = button.node
		if node == null:
			continue

		for connection in node.connections:
			var target = _find_button(connection.x, connection.y)
			if target == null:
				continue

			var map_line = MapManager.MAP_LINE.instantiate() as MapLine
			line_container.add_child(map_line)
			map_line.setup_connection(button, target)

## 根据 layer 和 node_index 查找对应的 MapNodeButton
func _find_button(layer: int, node_index: int) -> MapNodeButton:
	for button in map_node_buttons:
		if button.layer == layer and button.index == node_index:
			return button
	return null


## 处理鼠标拖拽：左键按住上下拖动地图，仅影响y轴
func _handle_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_start_mouse_y = event.position.y
			_drag_start_content_y = content.position.y
			if _scroll_tween:
				_scroll_tween.kill()
			accept_event()
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_dragging = false
			return
		var target_y: float = _drag_start_content_y + event.position.y - _drag_start_mouse_y
		_scroll_content_to(target_y)


## 将地图内容滚动到目标y坐标，限制视口始终在背景图范围内
func _scroll_content_to(target_y: float) -> void:
	content.position.y = _get_clamped_y(target_y)


## 将地图内容滚动到目标y坐标，限制视口始终在背景图范围内，包含tween动画
func _scroll_content_by_tween(target_y: float) -> void:
	var y: float = _get_clamped_y(target_y)
	if _scroll_tween:
		_scroll_tween.kill()
	_scroll_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	_scroll_tween.tween_property(content, "position:y", y, 0.5)


## 计算限制在视口范围内的目标y坐标
func _get_clamped_y(target_y: float) -> float:
	var min_y: float = size.y - bg.size.y
	return clampf(target_y, minf(min_y, 0.0), 0.0)

#endregion
