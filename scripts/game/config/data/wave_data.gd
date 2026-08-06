class_name WaveData
extends GameConfigData

var id: int
var monster_ids: PackedInt32Array  # [1, 2]
var counts: PackedInt32Array  # [10, 5] — 对应每种怪物的数量
var spawn_interval: float
var start_time: float


static func from_dict(dict: Dictionary) -> WaveData:
	var obj := WaveData.new()
	obj.id = _to_int(dict.get("ID", 0))
	obj.monster_ids = parse_int_array(_to_str(dict.get("MonsterIDs", "")))
	obj.counts = parse_int_array(_to_str(dict.get("Counts", "")))
	obj.spawn_interval = _to_float(dict.get("SpawnInterval", 0))
	obj.start_time = _to_float(dict.get("StartTime", 0))
	return obj
