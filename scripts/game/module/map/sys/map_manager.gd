extends Node

const BATTLE_TEXTURE: Texture = preload("res://assets/icon/tool_sword_b.png")
const SHOP_TEXTURE: Texture = preload("res://assets/icon/tool_wrench.png")
const FORGE_TEXTURE: Texture = preload("res://assets/icon/tool_hammer.png")

const MAP_LINE: PackedScene = preload("res://scene/map/map_line.tscn")

signal map_node_seleceted(node: MapNode)

## 当前地图id
var current_map_id: int = 0
## 当前地图的所有地图节点
var current_map_nodes: Array[MapNode] = []
## 当前进入的地图节点
var current_map_node: MapNode = null

## 根据地图id初始化当前地图管理器
func init_map(map_id: int) -> void:
	current_map_id = map_id
	current_map_nodes.clear()
	current_map_node = null
	var map_data: Dictionary = GameConfig.map_nodes[map_id]
	for layer_index in map_data:
		for node_index in map_data[layer_index]:
			current_map_nodes.push_back(MapNode.init_from_dict(map_data[layer_index][node_index]))


## 判断当前节点是否为地图最顶层
func is_map_final_node() -> bool:
	var max_layer: int = get_max_layer()
	return current_map_node.layer_index >= max_layer


## 构建所有节点的字典索引，键为 "layer-node"
func build_node_index() -> Dictionary:
	var index: Dictionary = {}
	for node in current_map_nodes:
		var key: String = "%d-%d" % [node.layer_index, node.node_index]
		index[key] = node
	return index

## 获取指定层级的所有节点
func get_layer_nodes(layer: int) -> Array[MapNode]:
	var result: Array[MapNode] = []
	for node in current_map_nodes:
		if node.layer_index == layer:
			result.append(node)
	result.sort_custom(func(a, b): return a.node_index < b.node_index)
	return result

## 获取最大层编号
func get_max_layer() -> int:
	var max_layer: int = 0
	for node in current_map_nodes:
		if node.layer_index > max_layer:
			max_layer = node.layer_index
	return max_layer

## 检查目标节点是否在当前节点的Connections中
func is_node_reachable(node: MapNode) -> bool:
	if node == null:
		return false

	var target_key: Vector2i = Vector2i(node.layer_index, node.node_index)
	# 尚未选中任何节点时，只有起始节点可选
	if current_map_node == null:
		return target_key == Vector2i.ZERO

	for conn in current_map_node.connections:
		if conn == target_key:
			return true
	return false

func check_and_init_next_map() -> bool:
	var map_id = current_map_id + 1
	var map_data: Dictionary = GameConfig.map_nodes[map_id]
	if map_data == null:
		return false

	init_map(map_id)
	return true
