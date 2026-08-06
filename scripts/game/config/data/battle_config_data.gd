class_name BattleConfigData
extends GameConfigData

var id: int
var wave_id: int
var monster_id: int
var limit: float
var interval: float
var count: int

static func from_dict(dict: Dictionary) -> BattleConfigData:
	var obj := BattleConfigData.new()
	obj.id = _to_int(dict.get("ID", 0))
	obj.wave_id = _to_int(dict.get("WaveID", 0))
	obj.monster_id = _to_int(dict.get("MonsterID", 0))
	obj.limit = _to_float(dict.get("Limit", 0))
	obj.interval = _to_float(dict.get("Interval", 0))
	obj.count = _to_int(dict.get("Count", 0))
	return obj
