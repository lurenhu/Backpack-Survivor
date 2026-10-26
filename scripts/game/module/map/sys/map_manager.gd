extends Node

const BATTLE_TEXTURE: Texture = preload("res://assets/res/maps/UI/战斗.png")
const SHOP_TEXTURE: Texture = preload("res://assets/res/maps/UI/商店.png")
const FORGE_TEXTURE: Texture = preload("res://assets/icon/tool_wrench.png")

const MAP_LINE: PackedScene = preload("res://scene/map/map_line.tscn")

## 当前地图id
var current_map_id: int = 0
## 当前地图的所有地图节点
var current_map_nodes: Array[MapNode] = []
## 当前进入的地图节点
var current_map_node: MapNode = null

## 根据地图id初始化当前地图管理器
func init_map(map_id: int) -> bool:
	if not can_initialize(map_id):
		return false
	current_map_id = map_id
	current_map_nodes.clear()
	current_map_node = null
	var map_data: Dictionary = GameConfig.map_nodes[map_id]
	for layer_index in map_data:
		for node_index in map_data[layer_index]:
			current_map_nodes.push_back(MapNode.init_from_dict(map_data[layer_index][node_index]))
	return true


func clear_map() -> void:
	current_map_id = 0
	current_map_nodes.clear()
	current_map_node = null


func can_initialize(map_id: int) -> bool:
	var data: Dictionary = GameConfig.map_nodes.get(map_id, {})
	if data.is_empty() or not data.has(0) or not data[0].has(0):
		return false
	for layer in data:
		for index in data[layer]:
			var row: MapNodeData = data[layer][index]
			if row == null or row.map_id != map_id or row.layer != layer or row.node_index != index:
				return false
			if row.node_type not in ["shop", "forge", "battle"]:
				return false
			for connection in row.connections:
				if connection.x <= layer or not data.has(connection.x) or not data[connection.x].has(connection.y):
					return false
	var path := get_map_scene_path(map_id)
	if not ResourceLoader.exists(path, "PackedScene"):
		return false
	var scene := load(path) as PackedScene
	return scene != null and scene.can_instantiate()


func get_map_scene_path(map_id: int) -> String:
	var path := "res://scene/map/map_%s.tscn" % map_id
	return path if ResourceLoader.exists(path, "PackedScene") else "res://scene/map/map.tscn"


func visit_node(node: MapNode) -> bool:
	if not is_node_reachable(node):
		return false
	node.visited = true
	current_map_node = node
	return true


## 判断当前节点是否为地图最顶层
func is_map_final_node() -> bool:
	var max_layer: int = get_max_layer()
	return current_map_node != null and current_map_node.layer_index >= max_layer


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
	if node == null or node.visited or node.map_id != current_map_id or node not in current_map_nodes:
		return false

	var target_key: Vector2i = Vector2i(node.layer_index, node.node_index)
	# 尚未选中任何节点时，只有起始节点可选
	if current_map_node == null:
		return target_key == Vector2i.ZERO

	for conn in current_map_node.connections:
		if conn == target_key:
			return true
	return false

## 只查询是否配置了下一张地图；缺损配置交给进入时校验，不误判为通关。
func get_next_map_id() -> int:
	var next_id := current_map_id + 1
	return next_id if GameConfig.map_nodes.has(next_id) else 0


func find_map_node(map_id: int, layer: int, index: int) -> MapNode:
	for map: MapNode in current_map_nodes:
		if map.map_id == map_id and map.layer_index == layer and map.node_index == index:
			return map
	return null
