class_name ConfigLoader
extends RefCounted
## CSV 资源适配与候选数据构建；不修改 GameConfig，也不实例化游戏实体。

const TABLES: Dictionary = {
	"equipment": {"file": "equipments.csv", "keys": ["ID"], "fields": {"ID": "id", "Name": "text", "Shape": "shape", "Rarity": "uint", "Attr": "attrs", "Price": "uint", "Source": "texture", "Type": "equipment_type"}},
	"monsters": {"file": "monsters.csv", "keys": ["ID"], "fields": {"ID": "id", "Name": "text", "Attr": "attrs", "GoldDrop": "uint", "Source": "scene"}},
	"characters": {"file": "characters.csv", "keys": ["ID"], "fields": {"ID": "id", "Name": "text", "Attr": "attrs", "BackpackShape": "backpack_shape", "InitEquipments": "optional_ids", "FramePath": "frames", "Illustration": "optional_texture"}},
	"pickups": {"file": "pickup.csv", "keys": ["ID"], "fields": {"ID": "id", "Name": "text", "Type": "pickup_type", "Source": "frames", "Collision": "collision"}},
	"shops": {"file": "shop.csv", "keys": ["ID"], "fields": {"ID": "id", "EquipmentIDs": "ids"}},
	"forges": {"file": "equipment_forge.csv", "keys": ["EquipmentID"], "fields": {"EquipmentID": "id", "MaterialIDs": "ids", "Coin": "uint"}},
	"battles": {"file": "battle.csv", "keys": ["ID", "WaveID", "MonsterID"], "fields": {"ID": "id", "WaveID": "id", "MonsterID": "id", "Limit": "positive", "Interval": "nonnegative", "Count": "uint"}},
	"map_nodes": {"file": "map_data.csv", "keys": ["MapID", "LayerIndex", "NodeIndex"], "fields": {"MapID": "id", "LayerIndex": "uint", "NodeIndex": "uint", "NodeType": "node_type", "ConfigID": "id", "Connections": "connections"}},
}

var _reader: Callable


## 可注入独立数据源进行测试，默认只读取导入后的资源。
func _init(reader: Callable = Callable()) -> void:
	_reader = reader if reader.is_valid() else _read_table


func load_all() -> ConfigLoadResult:
	var tables := {}
	for table: String in TABLES:
		tables[table] = _reader.call("res://config/" + TABLES[table].file)
	return build(tables)


func build(tables: Dictionary) -> ConfigLoadResult:
	var result := ConfigLoadResult.new()
	var validator := ConfigValidator.new(result)
	var normalized := {}
	# 检查全部表，汇总原始记录错误；格式不合法时不执行依赖它的跨表检查。
	for table: String in TABLES:
		normalized[table] = validator.validate_records(table, tables.get(table))
	if result.has_errors():
		return result
	var candidate := ConfigSnapshot.new()
	var factories := {
		"equipment": EquipmentData.from_dict, "monsters": MonsterData.from_dict,
		"characters": CharacterData.from_dict, "pickups": PickupData.from_dict,
		"shops": ShopConfigData.from_dict, "forges": EquipmentForgeData.from_dict,
		"battles": BattleConfigData.from_dict, "map_nodes": MapNodeData.from_dict,
	}
	for table: String in TABLES:
		candidate.set(table, GameConfigData.build_nested_dict(normalized[table], PackedStringArray(TABLES[table]["keys"]), factories[table]))
	validator.validate_snapshot(candidate)
	if not result.has_errors():
		result.snapshot = candidate
	return result


func _read_table(path: String) -> Variant:
	if not ResourceLoader.exists(path):
		return null
	var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if resource == null:
		return null
	# 允许导入插件保留自己的 Resource 类型；只适配 records 接口。
	for property in resource.get_property_list():
		if property.name == "records":
			return resource.get("records")
	return null
