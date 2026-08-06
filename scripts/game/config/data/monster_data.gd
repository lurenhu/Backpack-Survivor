class_name MonsterData
extends GameConfigData

var id: int
var name: String
var attr: Dictionary  # {"HP": 30, "ATK": 5, "SPD": 90}
var gold_drop: int
var source: String  # .tscn scene path


static func from_dict(dict: Dictionary) -> MonsterData:
	var obj := MonsterData.new()
	obj.id = _to_int(dict.get("ID", 0))
	obj.name = _to_str(dict.get("Name", ""))
	obj.attr = parse_kv_string(_to_str(dict.get("Attr", "")))
	obj.gold_drop = _to_int(dict.get("GoldDrop", 0))
	obj.source = _to_str(dict.get("Source", ""))
	return obj
