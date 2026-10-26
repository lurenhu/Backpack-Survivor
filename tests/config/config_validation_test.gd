extends Node

const FIXTURE := preload("res://tests/config/config_test_fixture.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var original := FIXTURE.tables()
	var result := ConfigLoader.new().build(original)
	if not _check(result.success and result.issues.is_empty(), "all shipping tables must pass: " + result.describe()):
		return
	if not _check(result.snapshot.equipment.size() == 28 and result.snapshot.map_nodes.size() == 1, "all tables must reach one candidate snapshot"):
		return
	# 每个用例在原始记录层注入错误，不能依赖宽松的 Data 转换发现问题。
	var cases := [
		["equipment", 0, "ID", "1.5", &"invalid_value"],
		["equipment", 0, "ID", "2147483648", &"invalid_value"],
		["equipment", 0, "Price", "-1", &"invalid_value"],
		["equipment", 0, "Shape", "1,0;1", &"invalid_shape"],
		["equipment", 0, "Shape", "0;0", &"invalid_shape"],
		["equipment", 0, "Shape", "1;abc", &"invalid_shape"],
		["equipment", 0, "Attr", "ATK:nan", &"invalid_value"],
		["equipment", 0, "Attr", "ATK:1,ATK:2", &"duplicate_attribute"],
		["equipment", 0, "Type", "UNKNOWN", &"invalid_enum"],
		["equipment", 1, "Attr", "SHOOTER_TYPE:INVALID", &"invalid_enum"],
		["equipment", 1, "Attr", "BULLET_TYPE:INVALID", &"invalid_enum"],
		["equipment", 1, "Attr", "SHOOT_INTERVAL:0,BULLET_SPEED:10", &"invalid_value"],
		["equipment", 0, "Source", "res://missing.png", &"invalid_resource"],
		["equipment", 0, "Source", "res://scene/battle/entities/enemy_slime.tscn", &"invalid_resource"],
		["characters", 0, "BackpackShape", "1,1,1,1,1,1,1,1,1", &"invalid_shape"],
		["characters", 0, "InitEquipments", "1,abc,3", &"invalid_value"],
		["characters", 0, "InitEquipments", "999", &"invalid_reference"],
		["characters", 0, "InitEquipments", "1,1,1,1,1", &"initial_inventory_full"],
		["characters", 0, "Attr", "HP:0,SPD:10", &"invalid_value"],
		["monsters", 0, "Source", "res://icon.svg", &"invalid_resource"],
		["shops", 0, "EquipmentIDs", "", &"invalid_value"],
		["shops", 0, "EquipmentIDs", "999", &"invalid_reference"],
		["forges", 0, "EquipmentID", "999", &"invalid_reference"],
		["forges", 0, "MaterialIDs", "999", &"invalid_reference"],
		["forges", 0, "Coin", "-1", &"invalid_value"],
		["battles", 0, "MonsterID", "999", &"invalid_reference"],
		["battles", 0, "Limit", "0", &"invalid_value"],
		["battles", 0, "Interval", "inf", &"invalid_value"],
		["battles", 0, "Count", "1.5", &"invalid_value"],
		["map_nodes", 0, "Connections", "abc-1", &"invalid_value"],
		["map_nodes", 0, "Connections", "1-0,1-0", &"duplicate_connection"],
		["map_nodes", 0, "Connections", "8-9", &"invalid_connection"],
		["map_nodes", 0, "Connections", "0-0", &"invalid_connection"],
		["map_nodes", 0, "Connections", "", &"dead_end"],
		["map_nodes", 0, "NodeType", "unknown", &"invalid_enum"],
		["map_nodes", 0, "ConfigID", "999", &"invalid_reference"],
		["pickups", 0, "Type", "INVALID", &"invalid_enum"],
	]
	for test in cases:
		var tables := original.duplicate(true)
		tables[test[0]][test[1]][test[2]] = test[3]
		result = ConfigLoader.new().build(tables)
		if not _check(not result.success and result.snapshot == null and FIXTURE.has_issue(result, test[4]), "bad field must reject candidate: %s / %s / %s: %s" % [test[0], test[2], test[3], result.describe()]):
			return
	for table: String in ConfigLoader.TABLES:
		var tables := original.duplicate(true)
		tables[table].append(tables[table][0].duplicate(true))
		result = ConfigLoader.new().build(tables)
		if not _check(not result.success and FIXTURE.has_issue(result, &"duplicate_key"), "duplicate complete key must be rejected for " + table):
			return
		var issue: ConfigIssue
		for candidate in result.issues:
			if candidate.code == &"duplicate_key":
				issue = candidate
		if not _check(issue.file.ends_with(ConfigLoader.TABLES[table].file) and issue.record_index == tables[table].size() and not issue.record_key.is_empty() and not issue.field.is_empty(), "diagnostic must retain file, record index, key and field"):
			return
	var missing := original.duplicate(true)
	var numeric_duplicate := original.duplicate(true)
	numeric_duplicate.equipment[1].ID = "01"
	if not _check(FIXTURE.has_issue(ConfigLoader.new().build(numeric_duplicate), &"duplicate_key"), "numerically equivalent IDs must collide before index construction"):
		return
	missing.equipment[0].erase("Price")
	missing.shops[0].erase("EquipmentIDs")
	result = ConfigLoader.new().build(missing)
	if not _check(FIXTURE.has_issue(result, &"missing_field", "Price") and FIXTURE.has_issue(result, &"missing_field", "EquipmentIDs"), "independent tables must report errors in one pass"):
		return
	var malformed := original.duplicate(true)
	malformed.equipment = [null]
	malformed.shops = "not an array"
	result = ConfigLoader.new().build(malformed)
	if not _check(FIXTURE.has_issue(result, &"invalid_record") and FIXTURE.has_issue(result, &"invalid_table"), "malformed resources must return diagnostics, not crash"):
		return
	var wave_tables := original.duplicate(true)
	var wave: Dictionary = wave_tables.battles[0].duplicate(true)
	wave.MonsterID = "2"
	wave.Limit = str(float(wave.Limit) + 1.0)
	wave_tables.battles.append(wave)
	result = ConfigLoader.new().build(wave_tables)
	if not _check(FIXTURE.has_issue(result, &"inconsistent_wave"), "same-wave limits must agree"):
		return
	var recipe_tables := original.duplicate(true)
	var recipe: Dictionary = recipe_tables.forges[0].duplicate(true)
	recipe.EquipmentID = "5"
	recipe.MaterialIDs = "3,1"
	recipe_tables.forges.append(recipe)
	if not _check(FIXTURE.has_issue(ConfigLoader.new().build(recipe_tables), &"ambiguous_recipe"), "material order cannot hide ambiguous recipes"):
		return
	var no_start := original.duplicate(true)
	no_start.map_nodes.pop_front()
	if not _check(FIXTURE.has_issue(ConfigLoader.new().build(no_start), &"missing_start_node"), "map must have node 0-0"):
		return
	# 兼容性边界：组合键允许父级重复、空立绘、零怪波次、缺省发射类型、无下一地图。
	var valid := original.duplicate(true)
	valid.characters[0].Illustration = ""
	valid.battles[0].Count = "0"
	valid.battles[0].Interval = "0"
	valid.equipment[2].Attr += ",NEW_ATTRIBUTE:1"
	result = ConfigLoader.new().build(valid)
	if not _check(result.success and FIXTURE.has_issue(result, &"unknown_attribute"), "optional/default values and warnings must not prevent publication"):
		return
	valid.forges = []
	if not _check(ConfigLoader.new().build(valid).success, "a game with no forge recipes is valid"):
		return
	if not _check(original.characters[0].Illustration != "" and str(original.battles[0].Count) != "0", "test edits must not mutate imported records"):
		return
	print("PASS: shipping configuration, strict raw fields, composite duplicates, resources, references, shapes, inventory fit, wave/map/recipe rules and compatibility")
	get_tree().quit(0)


func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("CONFIG VALIDATION TEST FAILED: " + message)
		get_tree().quit(1)
	return ok
