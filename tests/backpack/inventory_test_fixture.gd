extends RefCounted
## 仅测试使用：构造可控网格，其余操作全部经过正式业务入口。

static func reset(cols: int = 8, rows: int = 6) -> void:
	BackpackManager.init_backpack(1)
	for item in BackpackManager.backpack_equip.values():
		BackpackManager.remove_equipment(item)
	BackpackManager._inventory.grids[BackpackManager.GridType.PACKAGE] = GridRules.rectangle(cols, rows)
	BackpackManager._inventory.grids[BackpackManager.GridType.STAGE] = GridRules.rectangle(cols, rows)
	BackpackManager.set_gold(100)


static func expand_backpack() -> void:
	var grid := GridRules.rectangle(12, 8)
	for item in BackpackManager.backpack_equip.values():
		GridRules.mark(item.shape, item.grid_pos, grid, 1)
	BackpackManager._inventory.grids[BackpackManager.GridType.PACKAGE] = grid


static func add(config_id: int, area: int = BackpackManager.GridType.PACKAGE) -> Equipment:
	var shape: Array[Array] = GameConfig.equipment[config_id].shape
	var pos := GridRules.find_position(shape, BackpackManager.get_grid(area))
	var result := BackpackManager.grant_equipment(config_id, area, pos)
	assert(result.success, "test equipment must fit")
	return BackpackManager.get_equipment(result.added_ids[0])
