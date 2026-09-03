extends Node
## 单例：背包管理器，核心玩法系统——管理网格、装备放置/移除/旋转，属性重算

## 网格类型
enum GridType {
	NONE = -1,
	PACKAGE = 0,
	STAGE,
	SHOP,
	FORGE_TABLE,
	FORGE_REWARD,
}


const CELL_SIZE: int = 48 # 当个网格宽度
const BACKPACK_COLS: int = 8 # 背包网格的列数
const BACKPACK_ROWS: int = 6 # 背包网格的行数
const STAGE_COLS: int = 8 # 闲置区网格的列数
const STAGE_ROWS: int = 4 # 闲置区网格的行数
const FORGE_COLS: int = 8 # 锻造台网格的列数
const FORGE_ROWS: int = 4 # 锻造台网格的行数
const INITIAL_GRID_COST: int = 10 # 首个背包网格的购买价格
const GRID_NEIGHBOR_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.DOWN,
	Vector2i.LEFT,
	Vector2i.RIGHT,
]

signal equip_changed() # 网格区域装备发生变化（包括但不限于增加，减少，移动）
signal grid_purchase_state_changed() # 网格购买模式、价格或已解锁网格发生变化
signal gold_changed(current_gold: int)

var _gold: int = 0
var gold: int:
	get:
		return _gold

## 背包内的网格占用状态 0为未占用 1为占用
var backpack_grid: Array[Array] = []
## 背包内的装备数据 Vector2i 该装备左上角网格坐标 : Equipment 装备数据
var backpack_equip: Dictionary[Vector2i, Equipment] = {}
## 闲置区内的网格占用状态 0为未占用 1为占用
var stage_grid: Array[Array] = []
## 闲置区内的装备数据 Vector2i 该装备左上角网格坐标 : Equipment 装备数据
var stage_equip: Dictionary[Vector2i, Equipment] = {}
## 锻造台内的网格占用状态 
var forge_grid: Array[Array] = []
## 锻造台区内的装备数据 Vector2i 该装备左上角网格坐标 : Equipment 装备数据
var forge_equip: Dictionary[Vector2i, Equipment] = {}
## 当前背包中所有被动装备的属性合计
var equipment_attrs: AttrContainer = AttrContainer.new()
## 下一个背包网格的购买价格
var grid_cost: int = INITIAL_GRID_COST
## 是否处于背包网格购买状态
var is_grid_purchase_mode: bool = false

## 所有装备（背包）的合并视图，供外部遍历
var equipments: Dictionary:
	get:
		var all: Dictionary = {}
		for key in backpack_equip:
			all[key] = backpack_equip[key]
		return all


func set_gold(amount: int) -> void:
	var next_gold := maxi(amount, 0)
	if gold == next_gold:
		return
	_gold = next_gold
	gold_changed.emit(gold)


func add_gold(amount: int) -> bool:
	if amount <= 0:
		return false
	set_gold(gold + amount)
	return true


func spend_gold(amount: int) -> bool:
	if amount <= 0 or gold < amount:
		return false
	set_gold(gold - amount)
	return true

#region 背包网格业务逻辑

## 初始化背包：根据角色配置设置网格布局、放置初始装备，并初始化闲置区4x8网格
func init_backpack(character_id: int) -> void:
	grid_cost = INITIAL_GRID_COST
	is_grid_purchase_mode = false
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

	var start_y: int = floori((BACKPACK_ROWS - layout.size()) / 2.0)
	var end_y: int = start_y + layout.size()
	var start_x: int = floori((BACKPACK_COLS - layout[0].size()) / 2.0)
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

	# 锻造网格初始化
	forge_grid = []
	for y in FORGE_ROWS:
		var row: Array = []
		row.resize(FORGE_COLS)
		row.fill(0)
		forge_grid.append(row)

	# 清空装备数据
	backpack_equip.clear()
	stage_equip.clear()

	# 放置初始装备
	var init_equip_ids: PackedInt32Array = char_config.init_equipments
	for eid in init_equip_ids:
		var equip: Equipment = Equipment.new(eid)
		var pos: Vector2i = find_position(equip.shape, backpack_grid)
		equip.state = GridType.PACKAGE
		equip.grid_pos = pos
		if pos.x >= 0:
			add_to_equip_grid(equip, pos)
	_notify_equipment_changed()
	grid_purchase_state_changed.emit()


## 设置背包网格购买状态
func set_grid_purchase_mode(enabled: bool) -> void:
	if is_grid_purchase_mode == enabled:
		return
	is_grid_purchase_mode = enabled
	grid_purchase_state_changed.emit()


## 获取所有与已拥有网格上下左右相邻的未拥有网格
func get_purchasable_grid_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in backpack_grid.size():
		for x in backpack_grid[y].size():
			if backpack_grid[y][x] == -1:
				continue
			var owned_pos := Vector2i(x, y)
			for direction in GRID_NEIGHBOR_DIRECTIONS:
				var neighbor := owned_pos + direction
				if not _is_backpack_grid_position_valid(neighbor):
					continue
				if backpack_grid[neighbor.y][neighbor.x] == -1 and neighbor not in result:
					result.append(neighbor)
	return result


## 购买指定背包网格；仅购买模式下的候选网格可以解锁
func purchase_grid(grid_pos: Vector2i) -> bool:
	if not is_grid_purchase_mode:
		return false
	if grid_pos not in get_purchasable_grid_cells():
		return false
	if not spend_gold(grid_cost):
		return false

	backpack_grid[grid_pos.y][grid_pos.x] = 0
	grid_cost *= 2
	grid_purchase_state_changed.emit()
	return true


func _is_backpack_grid_position_valid(grid_pos: Vector2i) -> bool:
	if grid_pos.y < 0 or grid_pos.y >= backpack_grid.size():
		return false
	return grid_pos.x >= 0 and grid_pos.x < backpack_grid[grid_pos.y].size()


## 添加进指定装备网格区域
## 注意equipment变量的引用，本方法会将equipment加入到对应维护的equipment字典中
func add_to_equip_grid(equipment: Equipment, pos: Vector2i) -> bool:
	var target_grid_type: GridType = equipment.state
	var grid_array: Array[Array]
	var equip_dict: Dictionary
	match target_grid_type:
		GridType.PACKAGE:
			grid_array = backpack_grid
			equip_dict = backpack_equip
		GridType.STAGE:
			grid_array = stage_grid
			equip_dict = stage_equip
		GridType.FORGE_TABLE:
			grid_array = forge_grid
			equip_dict = forge_equip
		_:
			return false

	if not can_place(equipment.shape, pos, grid_array):
		return false
	
	add_to_grid(equipment.shape, pos, grid_array)
	equip_dict[pos] = equipment
	_notify_equipment_changed()
	return true


## 从对应装备字典中移除指定装备并清理网格占用
func remove_equipment(equipment: Equipment) -> bool:
	var grid_array: Array[Array]
	var equip_dict: Dictionary
	match equipment.state:
		GridType.PACKAGE:
			grid_array = backpack_grid
			equip_dict = backpack_equip
		GridType.STAGE:
			grid_array = stage_grid
			equip_dict = stage_equip
		GridType.FORGE_TABLE:
			grid_array = forge_grid
			equip_dict = forge_equip
		_:
			return false

	if not equip_dict.has(equipment.grid_pos):
		return false
	remove_from_grid(equipment.shape, equipment.grid_pos, grid_array)
	equip_dict.erase(equipment.grid_pos)
	_notify_equipment_changed()
	return true


## 在同一个网格中移动装备
## 注意equipment变量的引用，本方法会将equipment加入到对应维护的equipment字典中
## equipment:移动后的装备信息
## origin_equipment:移动前的装备信息
func move_to_grid(equipment: Equipment, origin_equipment: Equipment) -> bool:
	if equipment.is_equal(origin_equipment):
		return false

	var origin_grid: Array[Array]
	var origin_equip: Dictionary
	match origin_equipment.state:
		GridType.PACKAGE:
			origin_grid = backpack_grid
			origin_equip = backpack_equip
		GridType.STAGE:
			origin_grid = stage_grid
			origin_equip = stage_equip
		GridType.FORGE_TABLE:
			origin_grid = forge_grid
			origin_equip = forge_equip
		_:
			return false
	
	var target_grid: Array[Array]
	var target_equip: Dictionary
	match equipment.state:
		GridType.PACKAGE:
			target_grid = backpack_grid
			target_equip = backpack_equip
		GridType.STAGE:
			target_grid = stage_grid
			target_equip = stage_equip
		GridType.FORGE_TABLE:
			target_grid = forge_grid
			target_equip = forge_equip
		_:
			return false

	var old_shape = origin_equipment.shape
	var old_pos = origin_equipment.grid_pos
	var new_shape = equipment.shape
	var new_pos = equipment.grid_pos

	remove_from_grid(old_shape, old_pos, origin_grid)

	if can_place(new_shape, new_pos, target_grid):
		add_to_grid(new_shape, new_pos, target_grid)
		origin_equip.erase(old_pos)
		target_equip[new_pos] = equipment
		_notify_equipment_changed()
		return true
	else:
		add_to_grid(old_shape, old_pos, origin_grid)
		return false


## 根据当前背包中的被动装备全量重算装备属性
func recalculate_equipment_attrs() -> void:
	equipment_attrs.reset()
	for equipment: Equipment in backpack_equip.values():
		var data: EquipmentData = GameConfig.equipment.get(equipment.id)
		if data == null:
			DebugUtility.warn("BackpackManager", "未找到装备配置: %s" % equipment.id)
			continue
		if data.type != EquipmentEffectType.Type.PASSIVE_ATTRIBUTE:
			continue
		for key in data.attr:
			var type := AttrType.get_type(String(key))
			if int(type) == -1:
				DebugUtility.warn("BackpackManager", "未知属性类型: %s" % key)
				continue
			var total := equipment_attrs.get_value(type) if equipment_attrs.has(type) else 0.0
			equipment_attrs.set_value(type, total + float(data.attr[key]))


## 先刷新装备属性，再通知所有装备消费者
func _notify_equipment_changed() -> void:
	recalculate_equipment_attrs()
	equip_changed.emit()


## 将屏幕坐标转换为网格坐标
func screen_to_grid(equipment_screen_pos: Vector2, grid_container_pos: Vector2) -> Vector2i:
	var local_pos: Vector2 = equipment_screen_pos - grid_container_pos
	return Vector2i(int(local_pos.x / CELL_SIZE), int(local_pos.y / CELL_SIZE))


## 将网格坐标通过全局坐标转换为CardContainer下的像素坐标
func grid_to_pixel(grid_pos: Vector2i, grid_container: Control, card_container: Control) -> Vector2:
	var cell_local: Vector2 = Vector2(grid_pos.x * BackpackManager.CELL_SIZE, grid_pos.y * BackpackManager.CELL_SIZE)
	var cell_global: Vector2 = grid_container.global_position + cell_local
	return cell_global - card_container.global_position


## 检查形状在网格指定位置是否可放置（边界、占用检查）
func can_place(shape: Array[Array], pos: Vector2i, grid: Array[Array]) -> bool:
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
func add_to_grid(shape: Array[Array], pos: Vector2i, grid: Array[Array]) -> void:
	for y in shape.size():
		for x in shape[y].size():
			if shape[y][x] == 1 and grid[pos.y + y][pos.x + x] == 0:
				grid[pos.y + y][pos.x + x] = 1


## 在网格中清除装备占用的格子
func remove_from_grid(shape: Array[Array], pos: Vector2i, grid: Array[Array]) -> void:
	for y in shape.size():
		for x in shape[y].size():
			if shape[y][x] == 1 and grid[pos.y + y][pos.x + x] == 1:
				grid[pos.y + y][pos.x + x] = 0


## 在网格中查找第一个可放置指定形状的位置，找不到返回(-1, -1)
func find_position(shape: Array[Array], grid: Array[Array]) -> Vector2i:
	if shape.is_empty() or grid.is_empty():
		return Vector2i(-1, -1)

	for y in grid.size():
		for x in grid[y].size():
			if grid[y][x] != -1:
				var pos: Vector2i = Vector2i(x, y)
				if can_place(shape, pos, grid):
					return pos

	return Vector2i(-1, -1)

#endregion
