class_name AttrContainer
extends RefCounted

var _values: Dictionary = {} # Type → float

# 设置指定属性值
func set_value(type: AttrType.Type, value: float) -> void:
	_values[type] = value

# 获取指定属性值，未设置时返回该类型的默认值
func get_value(type: AttrType.Type) -> float:
	return _values.get(type, AttrType.DEFAULTS.get(type, 0.0))

# 检查是否包含指定属性类型
func has(type: AttrType.Type) -> bool:
	return _values.has(type)

# 返回所有已设置的属性类型
func get_types() -> Array[AttrType.Type]:
	var types: Array[AttrType.Type] = []
	for key in _values.keys():
		types.append(key)
	return types

# 加法合并：将另一个容器的值累加到当前容器，返回新容器（不修改原容器）
func merge_add(other: AttrContainer) -> AttrContainer:
	var result := AttrContainer.new()
	for type in _values:
		result.set_value(type, _values[type])
	for type in other._values:
		result.set_value(type, result.get_value(type) + other._values[type])
	return result

# 乘法合并：将另一个容器的值按乘法叠加，返回新容器（用于百分比加成叠加）
func merge_multiply(other: AttrContainer) -> AttrContainer:
	var result := AttrContainer.new()
	for type in _values:
		result.set_value(type, _values[type])
	for type in other._values:
		var base: float = result.get_value(type)
		result.set_value(type, base * (1.0 + other._values[type]))
	return result

# 转为CSV字典格式（用于调试输出和序列化）
func to_csv_dict() -> Dictionary:
	var result: Dictionary = {}
	for type in _values:
		var key: String = AttrType.get_key(type)
		if not key.is_empty():
			result[key] = _values[type]
	return result

# 重置所有已设置属性为默认值
func reset() -> void:
	_values.clear()

# 深拷贝
func duplicate() -> AttrContainer:
	var copy := AttrContainer.new()
	for type in _values:
		copy.set_value(type, _values[type])
	return copy