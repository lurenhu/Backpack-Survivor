class_name EquipmentForgeData
extends GameConfigData

var equipment_id: int
var material_ids: PackedInt32Array
var coin: int


static func from_dict(dict: Dictionary) -> EquipmentForgeData:
	var obj := EquipmentForgeData.new()
	obj.equipment_id = _to_int(dict.get("EquipmentID", 0))
	obj.material_ids = parse_int_array(_to_str(dict.get("MaterialIDs", "")))
	obj.coin = _to_int(dict.get("Coin", 0))
	return obj