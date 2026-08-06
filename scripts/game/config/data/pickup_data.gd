class_name PickupData
extends GameConfigData

var id: int
var name: String
var type: String
var source: String
var collision: String


static func from_dict(dict: Dictionary) -> PickupData:
	var obj := PickupData.new()
	obj.id = _to_int(dict.get("ID", 0))
	obj.name = _to_str(dict.get("Name", ""))
	obj.type = _to_str(dict.get("Type", ""))
	obj.source = _to_str(dict.get("Source", ""))
	obj.collision = _to_str(dict.get("Collision", ""))
	return obj
