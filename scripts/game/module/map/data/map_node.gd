class_name MapNode
extends RefCounted
## 地图节点数据对象：持有单个节点的所有配置字段

var map_id: int = 0
var layer_index: int = 0
var node_index: int = 0
var node_type: String = ""
var config_id: int = 0
var connections: Array[Vector2i] = []
var visited: bool = false

## 从CSV行字典构造MapNode对象
static func init_from_dict(row: MapNodeData) -> MapNode:
	var node: MapNode = MapNode.new()
	node.map_id = row.map_id
	node.layer_index = row.layer
	node.node_index = row.node_index
	node.node_type = row.node_type
	node.config_id = row.config_id
	node.connections = row.connections
	return node
