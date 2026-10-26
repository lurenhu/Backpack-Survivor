class_name GameConfigData
extends RefCounted

#region 解析

static func parse_kv_string(raw: String, pair_delim: String = ",", kv_delim: String = ":") -> Dictionary:
	if raw.is_empty():
		return {}
	var result := {}
	for pair in raw.split(pair_delim):
		var parts := pair.split(kv_delim)
		if parts.size() != 2:
			continue
		var key := parts[0].strip_edges()
		var value = parts[1].strip_edges()
		if value.is_valid_int():
			result[key] = int(value)
		elif value.is_valid_float():
			result[key] = float(value)
		else:
			result[key] = value
	return result


static func parse_int_array(raw: String, delim: String = ",") -> PackedInt32Array:
	if raw.is_empty():
		return PackedInt32Array()
	var result := PackedInt32Array()
	for token in raw.split(delim):
		var trimmed := token.strip_edges()
		if trimmed.is_valid_int():
			result.append(int(trimmed))
	return result


static func parse_str_array(raw: String, delim: String = ",") -> PackedStringArray:
	if raw.is_empty():
		return PackedStringArray()
	var result := PackedStringArray()
	for token in raw.split(delim):
		result.append(token.strip_edges())
	return result


## 解析装备形状字符串为二维数组，格式: "1,1;1,1;1,1;1,1" 分号分隔行，逗号分隔列
static func parse_shape(shape_str: String) -> Array[Array]:
	var result: Array[Array] = []
	if shape_str.is_empty():
		return result
	for row_str in shape_str.split(";", false):
		var row: Array = []
		for cell_str in row_str.split(",", false):
			var trimmed := cell_str.strip_edges()
			row.append(int(trimmed) if trimmed.is_valid_int() else 0)
		result.append(row)
	return result


static func _to_int(v, default := 0) -> int:
	if v is int:
		return v
	if v is float:
		return int(v)
	if v is String and v.is_valid_int():
		return int(v)
	return default


static func _to_float(v, default := 0.0) -> float:
	if v is float:
		return v
	if v is int:
		return float(v)
	if v is String and v.is_valid_float():
		return float(v)
	return default

#endregion

static func _to_str(v, default := "") -> String:
	return str(v) if v != null else default


# 将 CSV 原始记录构建为嵌套字典
# key_columns: 用作键的列名列表，从左到右依次嵌套
#   - 无重复时: {ID值: DataObj}
#   - 第一列重复时: {第一列值: {第二列值: DataObj}}, 以此类推
# factory: 将单条记录转为数据对象的 Callable，如 EquipmentData.from_dict
static func build_nested_dict(records: Array, key_columns: PackedStringArray, factory: Callable) -> Dictionary:
	# 配置加载器提供带表名的诊断；独立调用也不能静默丢弃完整键冲突。
	var seen := {}
	if key_columns.is_empty():
		push_error("GameConfigData: missing key columns")
		return {}
	for record in records:
		var key: Array = []
		for column in key_columns:
			key.append(_to_dict_key(record.get(column)))
		if seen.has(key):
			push_error("GameConfigData: duplicate complete key %s" % [key])
			return {}
		seen[key] = true
	return _build_level(records, key_columns, 0, factory)


static func _build_level(records: Array, key_columns: PackedStringArray, depth: int, factory: Callable):
	if records.is_empty():
		return {}

	var column := key_columns[depth] if depth < key_columns.size() else ""
	var groups := {} # key -> [records]

	for record in records:
		var raw_key = record.get(column, "")
		var dict_key = _to_dict_key(raw_key)
		if not groups.has(dict_key):
			groups[dict_key] = []
		groups[dict_key].append(record)

	var result := {}
	for dict_key in groups:
		var group_records: Array = groups[dict_key]
		if depth + 1 < key_columns.size():
			result[dict_key] = _build_level(group_records, key_columns, depth + 1, factory)
		else:
			# 完整键唯一性已由入口检查，此处恰好一条记录。
			result[dict_key] = factory.call(group_records[0])

	return result


# 将 CSV 中的值转为字典键（自动识别 int/float/string）
static func _to_dict_key(v):
	if v is int or v is float:
		return v
	if v is String and v.is_valid_int():
		return int(v)
	if v is String and v.is_valid_float():
		return float(v)
	return str(v) if v != null else ""
