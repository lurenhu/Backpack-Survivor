class_name EquipmentData
extends GameConfigData

var id: int
var name: String
var shape: Array[Array]
var rarity: int
var attr: Dictionary # {"ATK": 5, "ROTATE_RADIUS": 90, ...}
var price: int
var source: String
var type: Equipment.EQUIPMENT_TYPE
var collision: String


static func from_dict(dict: Dictionary) -> EquipmentData:
	var obj := EquipmentData.new()
	obj.id = _to_int(dict.get("ID", 0))
	obj.name = _to_str(dict.get("Name", ""))
	obj.shape = parse_shape(_to_str(dict.get("Shape", "")))
	obj.rarity = _to_int(dict.get("Rarity", 0))
	obj.attr = parse_kv_string(_to_str(dict.get("Attr", "")))
	obj.price = _to_int(dict.get("Price", 0))
	obj.source = _to_str(dict.get("Source", ""))
	obj.type = pharse_type(_to_str(dict.get("Type", "")))
	obj.collision = _to_str(dict.get("Collision", ""))
	return obj

static func pharse_type(type_str: String) -> Equipment.EQUIPMENT_TYPE:
	match type_str:
		"SHOOTER":
			return Equipment.EQUIPMENT_TYPE.SHOOTER
		_:
			return Equipment.EQUIPMENT_TYPE.ROTATE
