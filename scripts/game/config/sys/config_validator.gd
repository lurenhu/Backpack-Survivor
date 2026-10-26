class_name ConfigValidator
extends RefCounted
## 先检查原始字段，再检查候选对象；只读配置，不依赖任何 Autoload 状态。

var _result: ConfigLoadResult
var _locations: Dictionary = {}
var _resources: Dictionary = {}
var _table: String
var _record_index: int
var _key: String


func _init(result: ConfigLoadResult) -> void:
	_result = result


func validate_records(table: String, records: Variant) -> Array:
	_table = table
	_record_index = 0
	_key = ""
	_locations[table] = {}
	var accepted: Array = []
	if not records is Array:
		_error(&"invalid_table", "", "无法读取包含 records 数组的配置资源。")
		return accepted
	if records.is_empty() and table != "forges":
		_error(&"empty_table", "", "必需的配置表不能为空。")
	var schema: Dictionary = ConfigLoader.TABLES[table]
	var seen := {}
	for i in records.size():
		_record_index = i + 1
		_key = ""
		if not records[i] is Dictionary:
			_error(&"invalid_record", "", "记录必须是字段字典。")
			continue
		var row: Dictionary = records[i].duplicate(true)
		var before := _error_count()
		var parts := PackedStringArray()
		for field: String in schema["keys"]:
			parts.append("%s=%s" % [field, row.get(field, "<缺失>")])
		_key = ",".join(parts)
		for field: String in schema.fields:
			var kind: String = schema.fields[field]
			if not row.has(field) or row[field] == null:
				if kind == "optional_texture":
					row[field] = ""
					continue
				_error(&"missing_field", field, "缺少必需字段。")
				continue
			if not (row[field] is String or row[field] is int or row[field] is float):
				_error(&"invalid_value", field, "字段必须是文本或数值。")
				continue
			var value := str(row[field]).strip_edges()
			if row[field] is float and is_finite(row[field]) and row[field] >= 0 and row[field] <= 2147483647 and row[field] == floor(row[field]) and kind in ["id", "uint"]:
				value = str(int(row[field]))
			row[field] = value
			_validate_field(field, value, kind)
		# 即使其他字段有错，也检查合法的完整键，保留重复记录的两个位置。
		var key_valid := true
		parts.clear()
		for field: String in schema["keys"]:
			var value := str(row.get(field, ""))
			if not _integer(value, 0 if field in ["LayerIndex", "NodeIndex"] else 1):
				key_valid = false
			else:
				parts.append(str(int(value)))
		if key_valid:
			var canonical := ":".join(parts)
			if seen.has(canonical):
				_error(&"duplicate_key", ",".join(schema["keys"]), "完整键重复，首次出现于数据记录 %d。" % seen[canonical])
			else:
				seen[canonical] = _record_index
				_locations[table][canonical] = [_record_index, _key]
		if _error_count() == before:
			accepted.append(row)
	return accepted


func _validate_field(field: String, value: String, kind: String) -> void:
	match kind:
		"id", "uint":
			if not _integer(value, 1 if kind == "id" else 0):
				_error(&"invalid_value", field, "应为%s整数，实际为 '%s'。" % ["正" if kind == "id" else "非负", value])
		"positive", "nonnegative":
			if not _number(value) or float(value) < 0 or (kind == "positive" and float(value) == 0):
				_error(&"invalid_value", field, "应为有限的%s数值，实际为 '%s'。" % ["正" if kind == "positive" else "非负", value])
		"text":
			if value.is_empty():
				_error(&"invalid_value", field, "文本不能为空。")
		"ids", "optional_ids":
			if value.is_empty() and kind == "optional_ids":
				return
			for token in value.split(","):
				if not _integer(token.strip_edges(), 1):
					_error(&"invalid_value", field, "列表包含非法编号 '%s'。" % token)
		"shape", "backpack_shape":
			_validate_shape(field, value, kind == "backpack_shape")
		"attrs":
			_validate_attrs(field, value)
		"equipment_type":
			if EquipmentEffectType.from_string(value) == EquipmentEffectType.Type.UNKNOWN:
				_error(&"invalid_enum", field, "未知装备效果类型 '%s'。" % value)
		"pickup_type":
			if value not in ["GOLD", "EXP"]:
				_error(&"invalid_enum", field, "未知拾取物类型 '%s'。" % value)
		"node_type":
			if value not in ["shop", "forge", "battle"]:
				_error(&"invalid_enum", field, "未知地图节点类型 '%s'。" % value)
		"connections":
			if value.is_empty():
				return
			var seen := {}
			for token in value.split(","):
				var parts := token.strip_edges().split("-")
				if parts.size() != 2 or not _integer(parts[0].strip_edges(), 0) or not _integer(parts[1].strip_edges(), 0):
					_error(&"invalid_value", field, "连接应为非负的 层号-节点号，实际为 '%s'。" % token)
					continue
				var key := "%d:%d" % [int(parts[0]), int(parts[1])]
				if seen.has(key):
					_error(&"duplicate_connection", field, "重复连接 '%s'。" % token)
				seen[key] = true
		"texture", "optional_texture", "frames", "collision", "scene":
			if kind == "optional_texture" and value.is_empty():
				return
			var types := {"texture": "Texture2D", "optional_texture": "Texture2D", "frames": "SpriteFrames", "collision": "Shape2D", "scene": "PackedScene"}
			_validate_resource(field, value, types[kind])


func _validate_shape(field: String, value: String, backpack: bool) -> void:
	var rows := value.split(";")
	var width := rows[0].split(",").size()
	var occupied := false
	var valid := true
	for row in rows:
		var cells := row.split(",")
		valid = valid and cells.size() == width
		for cell in cells:
			var token := cell.strip_edges()
			valid = valid and token in ["0", "1"]
			occupied = occupied or token == "1"
	if not valid or not occupied:
		_error(&"invalid_shape", field, "形状必须为等宽的 0/1 矩阵，且至少有一个占用格。")
	if backpack and (width > 8 or rows.size() > 6):
		_error(&"invalid_shape", field, "角色背包不能超过 8 列、6 行。")


func _validate_attrs(field: String, value: String) -> void:
	if value.is_empty():
		return
	var seen := {}
	for token in value.split(","):
		var pair := token.split(":")
		if pair.size() != 2 or pair[0].strip_edges().is_empty():
			_error(&"invalid_value", field, "属性应为 名称:值，实际为 '%s'。" % token)
			continue
		var name := pair[0].strip_edges()
		var raw := pair[1].strip_edges()
		if seen.has(name):
			_error(&"duplicate_attribute", field + "." + name, "属性重复，不能静默覆盖。")
		seen[name] = true
		if name == "SHOOTER_TYPE":
			if ShooterType.from_string(raw) == ShooterType.Type.UNKNOWN:
				_error(&"invalid_enum", field + "." + name, "未知发射器类型 '%s'。" % raw)
		elif name == "BULLET_TYPE":
			if BulletType.from_string(raw) == BulletType.Type.UNKNOWN:
				_error(&"invalid_enum", field + "." + name, "未知子弹类型 '%s'。" % raw)
		elif not _number(raw):
			_error(&"invalid_value", field + "." + name, "属性必须是有限数值，实际为 '%s'。" % raw)
		elif AttrType.get_type(name) == -1:
			_error(&"unknown_attribute", field + "." + name, "运行时尚未识别此属性。", &"warning")
		elif name in ["SHOOT_NUM", "PENETRATION_COUNT"] and not _integer(raw, 1):
			_error(&"invalid_value", field + "." + name, "数量必须是正整数。")
		elif name in ["HP", "SPD", "ATK", "ROTATE_RADIUS", "SHOOT_INTERVAL", "SHOOT_RADIUS", "BULLET_SPEED", "AREA_RADIUS", "AREA_INTERVAL", "EXPLOSION_DAMAGE", "EXPLOSION_RADIUS"] and float(raw) < 0:
			_error(&"invalid_value", field + "." + name, "数值不能为负。")


func _validate_resource(field: String, path: String, type: String) -> void:
	if path.is_empty() or not path.begins_with("res://") or not ResourceLoader.exists(path):
		_error(&"invalid_resource", field, "资源不存在：" + path)
		return
	if not _resources.has(path):
		_resources[path] = load(path)
	var resource: Resource = _resources[path]
	if resource == null or not resource.is_class(type):
		_error(&"invalid_resource", field, "资源应为 %s：%s" % [type, path])
	elif resource is PackedScene and not resource.can_instantiate():
		_error(&"invalid_resource", field, "场景无法实例化：" + path)


func validate_snapshot(data: ConfigSnapshot) -> void:
	for id: int in data.equipment:
		_at("equipment", str(id))
		var item: EquipmentData = data.equipment[id]
		match item.type:
			EquipmentEffectType.Type.SHOOTER:
				_positive_attrs(item.attr, ["SHOOT_INTERVAL", "BULLET_SPEED"])
			EquipmentEffectType.Type.AREA:
				_positive_attrs(item.attr, ["AREA_INTERVAL", "AREA_RADIUS"])
	for id: int in data.characters:
		_at("characters", str(id))
		var character: CharacterData = data.characters[id]
		_positive_attrs(character.attr, ["HP"])
		if _references(data.equipment, character.init_equipments, "InitEquipments"):
			_validate_initial_inventory(character, data)
	for id: int in data.monsters:
		_at("monsters", str(id))
		_positive_attrs(data.monsters[id].attr, ["HP"])
	for id: int in data.shops:
		_at("shops", str(id))
		_references(data.equipment, data.shops[id].equipment_ids, "EquipmentIDs")
	var recipes := {}
	for id: int in data.forges:
		_at("forges", str(id))
		var recipe: EquipmentForgeData = data.forges[id]
		_references(data.equipment, [recipe.equipment_id], "EquipmentID")
		_references(data.equipment, recipe.material_ids, "MaterialIDs")
		var materials := Array(recipe.material_ids)
		materials.sort()
		var key := str(materials)
		if recipes.has(key):
			_error(&"ambiguous_recipe", "MaterialIDs", "材料及数量与产物 %s 的配方相同。" % recipes[key])
		recipes[key] = id
	for battle_id: int in data.battles:
		for wave_id: int in data.battles[battle_id]:
			var limit := -1.0
			for monster_id: int in data.battles[battle_id][wave_id]:
				_at("battles", "%d:%d:%d" % [battle_id, wave_id, monster_id])
				var wave: BattleConfigData = data.battles[battle_id][wave_id][monster_id]
				_references(data.monsters, [monster_id], "MonsterID")
				if limit >= 0 and not is_equal_approx(limit, wave.limit):
					_error(&"inconsistent_wave", "Limit", "同一波次的时限必须一致。")
				limit = wave.limit
	_validate_maps(data)
	# 当前新局固定从地图 1 开始，战斗金币掉落固定引用拾取物 1。
	_at("map_nodes", "")
	if not data.map_nodes.has(1):
		_error(&"missing_start_map", "MapID", "缺少新局所需的地图 1。")
	_at("pickups", "1")
	if not data.pickups.has(1) or data.pickups[1].type != "GOLD":
		_error(&"invalid_gold_pickup", "Type", "战斗金币掉落需要 ID=1、Type=GOLD 的拾取物。")


func _validate_maps(data: ConfigSnapshot) -> void:
	for map_id: int in data.map_nodes:
		var layers: Dictionary = data.map_nodes[map_id]
		var max_layer: int = layers.keys().max()
		_at("map_nodes", "%d:0:0" % map_id)
		if not layers.has(0) or not layers[0].has(0):
			_error(&"missing_start_node", "NodeIndex", "地图缺少起点 0-0。")
		var reachable := {Vector2i.ZERO: true}
		var layer_ids := layers.keys()
		layer_ids.sort()
		for layer: int in layer_ids:
			for index: int in layers[layer]:
				_at("map_nodes", "%d:%d:%d" % [map_id, layer, index])
				var node: MapNodeData = layers[layer][index]
				if node.node_type == "shop":
					_references(data.shops, [node.config_id], "ConfigID")
				elif node.node_type == "battle":
					_references(data.battles, [node.config_id], "ConfigID")
				# forge 的 ConfigID 目前不引用独立表，配方按装备材料匹配。
				if layer < max_layer and node.connections.is_empty():
					_error(&"dead_end", "Connections", "非末层节点没有后续路径，会导致对局无法推进。")
				for target in node.connections:
					if target.x <= layer or not layers.has(target.x) or not layers[target.x].has(target.y):
						_error(&"invalid_connection", "Connections", "连接必须指向存在的后续层节点：%s。" % target)
					elif reachable.has(Vector2i(layer, index)):
						reachable[target] = true
				if not reachable.has(Vector2i(layer, index)):
					_error(&"unreachable_node", "Connections", "该节点无法从起点到达。", &"warning")


func _validate_initial_inventory(character: CharacterData, data: ConfigSnapshot) -> void:
	var shape := character.backpack_shape
	var grid := GridRules.rectangle(8, 6, -1)
	var offset := Vector2i((8 - shape[0].size()) / 2, (6 - shape.size()) / 2)
	for y in shape.size():
		for x in shape[y].size():
			if shape[y][x] == 1:
				grid[y + offset.y][x + offset.x] = 0
	# 与实际初始化一致：按配置顺序、原始朝向寻找第一个空位。
	for id in character.init_equipments:
		var item: EquipmentData = data.equipment[id]
		var pos := GridRules.find_position(item.shape, grid)
		if pos.x < 0:
			_error(&"initial_inventory_full", "InitEquipments", "初始装备 %d 无法按当前初始化规则放入背包。" % id)
			return
		GridRules.mark(item.shape, pos, grid, 1)


func _positive_attrs(attrs: Dictionary, keys: Array) -> void:
	for key: String in keys:
		if not attrs.has(key) or float(attrs[key]) <= 0:
			_error(&"invalid_value", "Attr." + key, "必须配置大于 0 的数值。")


func _references(target: Dictionary, ids: Variant, field: String) -> bool:
	var valid := true
	for id in ids:
		if not target.has(id):
			_error(&"invalid_reference", field, "引用的配置 %s 不存在。" % id)
			valid = false
	return valid


func _at(table: String, key: String) -> void:
	_table = table
	var location: Array = _locations[table].get(key, [0, key])
	_record_index = location[0]
	_key = location[1]


func _error(code: StringName, field: String, message: String, severity: StringName = &"error") -> void:
	_result.add_issue(code, "res://config/" + ConfigLoader.TABLES[_table].file, _record_index, _key, field, message, severity)


func _error_count() -> int:
	var count := 0
	for issue in _result.issues:
		if issue.severity == &"error":
			count += 1
	return count


func _integer(value: String, minimum: int) -> bool:
	# Data 中的编号数组和地图坐标使用 32 位整数，拒绝截断与溢出。
	return value.is_valid_int() and value.length() <= 10 and int(value) >= minimum and int(value) <= 2147483647


func _number(value: String) -> bool:
	return value.is_valid_float() and is_finite(float(value))
