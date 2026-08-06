class_name CharacterData
extends GameConfigData

var id: int
var name: String
var attr: Dictionary # {"HP": 100, "SPD": 300}
var backpack_shape: Array[Array] # "4x2"
var init_equipments: PackedInt32Array # [1, 1]
var frame_path: String
var descript: String
var illustration: String


static func from_dict(dict: Dictionary) -> CharacterData:
	var obj := CharacterData.new()
	obj.id = _to_int(dict.get("ID", 0))
	obj.name = _to_str(dict.get("Name", ""))
	obj.attr = parse_kv_string(_to_str(dict.get("Attr", "")))
	obj.backpack_shape = parse_shape(_to_str(dict.get("BackpackShape", "")))
	obj.init_equipments = parse_int_array(_to_str(dict.get("InitEquipments", "")))
	obj.frame_path = _to_str(dict.get("FramePath", ""))
	obj.descript = _to_str(dict.get("Descript", ""))
	obj.illustration = _to_str(dict.get("Illustration", ""))
	return obj
