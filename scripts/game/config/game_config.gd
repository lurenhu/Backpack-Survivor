class_name GameConfig
extends RefCounted

# 装备:  {ID: EquipmentData}
static var equipment: Dictionary
# 怪物:  {ID: MonsterData}
static var monsters: Dictionary
# 角色:  {ID: CharacterData}
static var characters: Dictionary
# 拾取物: {ID: PickupData}
static var pickups: Dictionary
# 商店配置: {ID: ShopConfigData}
static var shops: Dictionary
# 装备锻造: {EquipmentID: EquipmentForgeData}
static var forges: Dictionary
# 战斗配置: {ID: {WaveID: {MonsterID: BattleConfigData}}}
static var battles: Dictionary
# 地图节点: {MapID: {LayerIndex: {NodeIndex: MapNodeData}}}
static var map_nodes: Dictionary

static var _loaded := false


static func _init() -> void:
	_load_all()


static func _load_all() -> void:
	if _loaded:
		return
	_loaded = true

	_load_equipments()
	_load_monsters()
	_load_characters()
	_load_pickups()
	_load_shop_configs()
	_load_equipment_forges()
	_load_battle_configs()
	_load_map_nodes()


static func _load_csv(path: String) -> Array:
	if not ResourceLoader.exists(path):
		printerr("GameConfig: file not found: ", path)
		return []
	var res := load(path)
	if res == null:
		printerr("GameConfig: failed to load: ", path)
		return []
	return res.records if res.records != null else []


static func _load_equipments() -> void:
	var records := _load_csv("res://config/equipments.csv")
	equipment = GameConfigData.build_nested_dict(records, ["ID"], EquipmentData.from_dict)


static func _load_monsters() -> void:
	var records := _load_csv("res://config/monsters.csv")
	monsters = GameConfigData.build_nested_dict(records, ["ID"], MonsterData.from_dict)


static func _load_characters() -> void:
	var records := _load_csv("res://config/characters.csv")
	characters = GameConfigData.build_nested_dict(records, ["ID"], CharacterData.from_dict)


static func _load_pickups() -> void:
	var records := _load_csv("res://config/pickup.csv")
	pickups = GameConfigData.build_nested_dict(records, ["ID"], PickupData.from_dict)


static func _load_shop_configs() -> void:
	var records := _load_csv("res://config/shop.csv")
	shops = GameConfigData.build_nested_dict(records, ["ID"], ShopConfigData.from_dict)


static func _load_equipment_forges() -> void:
	var records := _load_csv("res://config/equipment_forge.csv")
	forges = GameConfigData.build_nested_dict(records, ["EquipmentID"], EquipmentForgeData.from_dict)


static func _load_battle_configs() -> void:
	var records := _load_csv("res://config/battle.csv")
	battles = GameConfigData.build_nested_dict(records, ["ID", "WaveID", "MonsterID"], BattleConfigData.from_dict)


static func _load_map_nodes() -> void:
	var records := _load_csv("res://config/map_data.csv")
	# MapID 全部为 1 会重复，LayerIndex 也有重复，三层嵌套: MapID -> LayerIndex -> NodeIndex -> Data
	map_nodes = GameConfigData.build_nested_dict(records, ["MapID", "LayerIndex", "NodeIndex"], MapNodeData.from_dict)
