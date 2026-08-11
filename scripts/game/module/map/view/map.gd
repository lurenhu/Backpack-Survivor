class_name Map
extends Control
## 地图场景脚本：加载地图数据，绘制节点和连线，处理选择交互

@onready var map_node_container: Control = $MapNodeContainer
@onready var line_container: Control = $LineContainer

var map_node_buttons: Array[MapNodeButton] = []

func _ready() -> void:
	_setup()
	update_map_nodes()

#region 公开方法

## 更新地图节点状态
func update_map_nodes():
	for button in map_node_buttons:
		button.update_map_node()

#endregion

#region 私有方法

## 初始化
func _setup():
	for child: MapNodeButton in map_node_container.get_children():
		map_node_buttons.append(child)
	_connect_map_node_with_line()

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

#endregion