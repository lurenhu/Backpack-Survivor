extends Node
## 单例：背包管理器，核心玩法系统——管理网格、装备放置/移除/旋转，属性重算

const CELL_SIZE: int = 32
const BACKPACK_COLS: int = 8
const BACKPACK_ROWS: int = 8
const STAGE_COLS: int = 8
const STAGE_ROWS: int = 4

signal equip_changed()

## 背包内的网格占用状态 0为未占用 1为占用
var backpack_grid: Array[Array] = []
## 背包内的装备数据 Vector2i 该装备左上角网格坐标 : Equipment 装备数据
var backpack_equip: Dictionary[Vector2i, Equipment] = {}
## 闲置区内的网格占用状态 0为未占用 1为占用
var stage_grid: Array[Array] = []
## 闲置区内的装备数据 Vector2i 该装备左上角网格坐标 : Equipment 装备数据
var stage_equip: Dictionary[Vector2i, Equipment] = {}

## 所有装备（背包）的合并视图，供外部遍历
var equipments: Dictionary:
	get:
		var all: Dictionary = {}
		for key in backpack_equip:
			all[key] = backpack_equip[key]
		return all

## ----------------------背包网格业务逻辑-------------------------

## 初始化背包：根据角色配置设置网格布局、放置初始装备，并初始化闲置区4x8网格
func init_backpack(character_id: int) -> void:
	var char_config: CharacterData = GameConfig.characters[character_id]
	if char_config == null:
		return

	# 解析角色背包形状，以此确定网格尺寸
	var layout: Array[Array] = char_config.backpack_shape
	if layout.is_empty():
		return

	# 初始化背包占用网格（全部置为-1=未启用）
	backpack_grid = []
	for y in BACKPACK_ROWS:
		var row: Array = []
		row.resize(BACKPACK_COLS)
		row.fill(-1)
		backpack_grid.append(row)

	var start_y: int = (BACKPACK_ROWS - layout.size()) / 2
	var end_y: int = start_y + layout.size()
	var start_x: int = (BACKPACK_COLS - layout[0].size()) / 2
	var end_x: int = start_x + layout[0].size()
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			backpack_grid[y][x] = 0

	# 初始化闲置区网格 4列x8行
	stage_grid = []
	for y in STAGE_ROWS:
		var row: Array = []
		row.resize(STAGE_COLS)
		row.fill(0)
		stage_grid.append(row)

	# 清空装备数据
	backpack_equip.clear()
	stage_equip.clear()

	# 放置初始装备
	var init_equip_ids: PackedInt32Array = char_config.init_equipments
	for eid in init_equip_ids:
		var equip: Equipment = Equipment.new(eid)
		if equip.shape.is_empty():
			continue
		var pos: Vector2i = _find_position(equip.shape, backpack_grid)
		if pos.x >= 0:
			add_to_backpack(equip, pos)
			equip.state = Equipment.EQUIPMENT_STATE.BACKPACK


## 在背包网格指定位置添加装备，更新占用数据并重算属性
func add_to_backpack(equip: Equipment, pos: Vector2i) -> bool:
	if equip.shape.is_empty():
		return false

	if not _can_place(equip.shape, pos, backpack_grid):
		return false

	equip.state = Equipment.EQUIPMENT_STATE.BACKPACK
	equip.grid_pos = pos
	backpack_equip[pos] = equip
	_add_to_grid(equip.shape, pos, backpack_grid)
	equip_changed.emit()
	return true


## 在闲置区网格指定位置添加装备，更新占用数据并重算属性
func add_to_stage(equip: Equipment, pos: Vector2i) -> bool:
	if equip.shape.is_empty():
		return false

	if not _can_place(equip.shape, pos, stage_grid):
		return false

	equip.state = Equipment.EQUIPMENT_STATE.STAGE
	equip.grid_pos = pos
	stage_equip[pos] = equip
	_add_to_grid(equip.shape, pos, stage_grid)
	equip_changed.emit()
	return true


## 从背包网格移除装备，释放占用格子并重算属性
func remove_from_backpack(equip: Equipment) -> bool:
	var pos: Vector2i = equip.grid_pos
	if not backpack_equip.has(pos):
		return false

	_remove_from_grid(equip.shape, pos, backpack_grid)
	backpack_equip.erase(pos)
	equip_changed.emit()
	return true


## 从闲置区网格移除装备，释放占用格子并重算属性
func remove_from_stage(equip: Equipment) -> bool:
	var pos: Vector2i = equip.grid_pos
	if not stage_equip.has(pos):
		return false

	_remove_from_grid(equip.shape, pos, stage_grid)
	stage_equip.erase(pos)
	equip_changed.emit()
	return true


## 在背包网格内移动装备到新位置，暂清旧位置后检查，失败则回退
func move_in_backpack(equip: Equipment, new_pos: Vector2i, rotated: bool, origin_shape: Array[Array]) -> bool:
	var old_pos: Vector2i = equip.grid_pos
	if old_pos == new_pos and !rotated:
		return false

	_remove_from_grid(origin_shape, old_pos, backpack_grid)
	backpack_equip.erase(old_pos)

	if _can_place(equip.shape, new_pos, backpack_grid):
		_add_to_grid(equip.shape, new_pos, backpack_grid)
		backpack_equip[new_pos] = equip
		equip.grid_pos = new_pos
		equip_changed.emit()
		return true
	else:
		_add_to_grid(origin_shape, old_pos, backpack_grid)
		return false


## 在闲置区网格内移动装备到新位置，暂清旧位置后检查，失败则回退
func move_in_stage(equip: Equipment, new_pos: Vector2i, rotated: bool, origin_shape: Array[Array]) -> bool:
	var old_pos: Vector2i = equip.grid_pos
	if old_pos == new_pos and !rotated:
		return false

	_remove_from_grid(origin_shape, old_pos, stage_grid)
	stage_equip.erase(old_pos)

	if _can_place(equip.shape, new_pos, stage_grid):
		_add_to_grid(equip.shape, new_pos, stage_grid)
		stage_equip[new_pos] = equip
		equip.grid_pos = new_pos
		equip_changed.emit()
		return true
	else:
		_add_to_grid(origin_shape, old_pos, stage_grid)
		return false


## 跨网格移动装备：从当前网格移除并添加到目标网格，失败则回退
func move_to_grid(equip: Equipment, target_pos: Vector2i, to_backpack: bool, origin_shape: Array[Array]) -> bool:
	var from_backpack: bool = equip.state == Equipment.EQUIPMENT_STATE.BACKPACK
	var source_grid: Array[Array] = backpack_grid if from_backpack else stage_grid
	var source_dict: Dictionary = backpack_equip if from_backpack else stage_equip
	var target_grid: Array[Array] = backpack_grid if to_backpack else stage_grid
	var target_dict: Dictionary = backpack_equip if to_backpack else stage_equip
	var old_pos: Vector2i = equip.grid_pos

	_remove_from_grid(origin_shape, old_pos, source_grid)
	source_dict.erase(old_pos)

	if _can_place(equip.shape, target_pos, target_grid):
		_add_to_grid(equip.shape, target_pos, target_grid)
		target_dict[target_pos] = equip
		equip.grid_pos = target_pos
		equip.state = Equipment.EQUIPMENT_STATE.BACKPACK if to_backpack else Equipment.EQUIPMENT_STATE.STAGE
		equip_changed.emit()
		return true
	else:
		_add_to_grid(origin_shape, old_pos, source_grid)
		return false


## 将屏幕坐标转换为网格坐标
func screen_to_grid(screen_pos: Vector2, grid_origin: Vector2) -> Vector2i:
	var local_pos: Vector2 = screen_pos - grid_origin
	return Vector2i(int(local_pos.x / CELL_SIZE), int(local_pos.y / CELL_SIZE))


## 检查形状在网格指定位置是否可放置（边界、占用检查）
func _can_place(shape: Array[Array], pos: Vector2i, grid: Array[Array]) -> bool:
	if shape.is_empty() or grid.is_empty():
		return false

	var rows: int = shape.size()
	var cols: int = shape[0].size()

	for y in rows:
		for x in cols:
			if shape[y][x] != 1:
				continue
			var grid_x: int = pos.x + x
			var grid_y: int = pos.y + y

			# 边界检查
			if grid_y < 0 or grid_y >= grid.size():
				return false
			if grid_x < 0 or grid_x >= grid[grid_y].size():
				return false

			# 占用检查
			if grid[grid_y][grid_x] != 0:
				return false

	return true


## 在网格中标记装备占用
func _add_to_grid(shape: Array[Array], pos: Vector2i, grid: Array[Array]) -> void:
	for y in shape.size():
		for x in shape[y].size():
			if shape[y][x] == 1 and grid[pos.y + y][pos.x + x] == 0:
				grid[pos.y + y][pos.x + x] = 1


## 在网格中清除装备占用的格子
func _remove_from_grid(shape: Array[Array], pos: Vector2i, grid: Array[Array]) -> void:
	for y in shape.size():
		for x in shape[y].size():
			if shape[y][x] == 1 and grid[pos.y + y][pos.x + x] == 1:
				grid[pos.y + y][pos.x + x] = 0


## 在网格中查找第一个可放置指定形状的位置，找不到返回(-1, -1)
func _find_position(shape: Array[Array], grid: Array[Array]) -> Vector2i:
	if shape.is_empty() or grid.is_empty():
		return Vector2i(-1, -1)

	for y in grid.size():
		for x in grid[y].size():
			if grid[y][x] != -1:
				var pos: Vector2i = Vector2i(x, y)
				if _can_place(shape, pos, grid):
					return pos

	return Vector2i(-1, -1)

## ----------------------背包属性计算业务逻辑-------------------------
