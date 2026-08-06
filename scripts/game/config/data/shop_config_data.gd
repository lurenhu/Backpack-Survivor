class_name ShopConfigData
extends GameConfigData

var id: int
var equipment_ids: PackedInt32Array


static func from_dict(dict: Dictionary) -> ShopConfigData:
	var obj := ShopConfigData.new()
	obj.id = _to_int(dict.get("ID", 0))
	obj.equipment_ids = parse_int_array(_to_str(dict.get("EquipmentIDs", "")))
	return obj
