extends RefCounted
## 复制真实资源中的原始记录；测试不改 CSV、不修改已发布的 Data 对象。

static func tables() -> Dictionary:
	var result := {}
	for table: String in ConfigLoader.TABLES:
		var resource := load("res://config/" + ConfigLoader.TABLES[table].file)
		result[table] = resource.records.duplicate(true)
	return result


static func loader(data: Dictionary) -> ConfigLoader:
	return ConfigLoader.new(func(path: String) -> Variant:
		for table: String in ConfigLoader.TABLES:
			if ConfigLoader.TABLES[table].file == path.get_file():
				return data.get(table)
		return null
	)


static func has_issue(result: ConfigLoadResult, code: StringName, field: String = "") -> bool:
	for issue in result.issues:
		if issue.code == code and (field.is_empty() or issue.field == field):
			return true
	return false
