class_name MapNodeData
extends GameConfigData

var map_id: int
var layer: int
var node_index: int
var node_type: String # "shop", "battle"
var config_id: int
var connections: Array[Vector2i] # [{"layer": 1, "node_index": 0}, ...]


static func from_dict(dict: Dictionary) -> MapNodeData:
	var obj := MapNodeData.new()
	obj.map_id = _to_int(dict.get("MapID", 0))
	obj.layer = _to_int(dict.get("LayerIndex", 0))
	obj.node_index = _to_int(dict.get("NodeIndex", 0))
	obj.node_type = _to_str(dict.get("NodeType", ""))
	obj.config_id = _to_int(dict.get("ConfigID", 0))
	obj.connections = _parse_connections(_to_str(dict.get("Connections", "")))
	return obj


static func _parse_connections(raw: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if raw.is_empty():
		return result
	for token in raw.split(","):
		var parts := token.strip_edges().split("-")
		if parts.size() != 2:
			continue
		result.append(Vector2i(int(parts[0]), int(parts[1])))
	return result
