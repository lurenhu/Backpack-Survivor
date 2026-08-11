class_name Package
extends Control
## 背包网格UI：根据BackpackManager数据刷新网格瓦片和装备卡片显示

const CARD_SCENE: PackedScene = preload("res://scene/shop/equipment_card.tscn")

@onready var backpack_grid_tile: TileMapLayer = $PakageGrid/GridTile
@onready var stage_grid_tile: TileMapLayer = $StageGrid/GridTile
@onready var backpack_container: Control = $PakageGrid
@onready var stage_container: Control = $StageGrid
@onready var card_container: Control = $CardContainer

# 背包网格装备卡片字典vector2i -> equipmentcard
var _backpack_cards: Dictionary[Vector2i, EquipmentCard] = {}
# 闲置区网格装备卡片字典vector2i -> equipmentcard
var _stage_cards: Dictionary[Vector2i, EquipmentCard] = {}

var _dragging_cards: Array[EquipmentCard] = []
var _drag_origin_grid_cells: Dictionary = {}

## 就绪时连接信号并初始化显示
func _ready() -> void:
	BackpackManager.equip_changed.connect(_on_equip_changed)
	_update_view()


## 每帧检查拖拽状态，有拖拽卡片时刷新网格高亮
func _process(_delta: float) -> void:
	if _dragging_cards.is_empty():
		return
	_update_all_grid_highlights()


#region 内部方法

## 刷新所有显示：网格瓦片和装备卡片
func _update_view() -> void:
	_update_backpack_grid()
	_update_stage_grid()
	_sync_backpack_cards()
	_sync_stage_cards()


## 根据backpack_grid数据刷新背包网格瓦片
func _update_backpack_grid() -> void:
	backpack_grid_tile.clear()
	var grid: Array[Array] = BackpackManager.backpack_grid
	for y in grid.size():
		for x in grid[y].size():
			if grid[y][x] != -1:
				backpack_grid_tile.set_cell(Vector2i(x, y), 1, Vector2i.ZERO)

## 根据stage_grid数据刷新闲置区网格瓦片
func _update_stage_grid() -> void:
	stage_grid_tile.clear()
	var grid: Array[Array] = BackpackManager.stage_grid
	for y in grid.size():
		for x in grid[y].size():
			if grid[y][x] != -1:
				stage_grid_tile.set_cell(Vector2i(x, y), 1, Vector2i.ZERO)

## 同步背包装备卡片：创建新卡片、移除已删除装备的卡片、更新位置
func _sync_backpack_cards() -> void:
	_sync_cards(BackpackManager.backpack_equip, _backpack_cards, backpack_container)


## 同步闲置区装备卡片：创建新卡片、移除已删除装备的卡片、更新位置
func _sync_stage_cards() -> void:
	_sync_cards(BackpackManager.stage_equip, _stage_cards, stage_container)


func _sync_cards(equip_dict: Dictionary[Vector2i, Equipment], card_dict: Dictionary[Vector2i, EquipmentCard], container: Control) -> void:
	# 添加equip_dict中存在但card_dict中不存在的装备卡片
	DebugUtility.info("current_container", "%s" % container.name)
	for equip in equip_dict.values():
		if _get_dict_card(equip, card_dict) == null:
			_add_equipment_card(equip, card_dict)

	# 删除card_dict中存在但equip_dict中不存在的装备卡片
	var to_remove: Array[Equipment] = []
	for card in card_dict.values():
		if not equip_dict.values().has(card.equipment):
			to_remove.append(card.equipment)
	for equip in to_remove:
		_remove_equipment_card(equip, card_dict)
	
	# 修正key值与grid_pos不匹配的卡片，同步position坐标
	for card_pos in card_dict.keys():
		var card: EquipmentCard = card_dict[card_pos]
		if card_pos != card.equipment.grid_pos:
			card_dict.erase(card_pos)
			card_dict[card.equipment.grid_pos] = card
			#DebugUtility.info("update_equip_card", "Equipment:%s, pos:%s" % [card.equipment, card.equipment.grid_pos])
		card.position = _grid_to_pixel(card.equipment.grid_pos, container) - card.get_rotate_offset()


## 添加卡片
func _add_equipment_card(equip: Equipment, card_dict: Dictionary[Vector2i, EquipmentCard]) -> void:
	var card: EquipmentCard = CARD_SCENE.instantiate()
	card_container.add_child(card)
	card.setup_by_equipment(equip)
	card.drag_dropped.connect(_on_card_dropped.bind(card))
	card.drag_state_changed.connect(_on_card_drag_state_changed.bind(card))
	card_dict[equip.grid_pos] = card
	DebugUtility.info("add_equip_card", "Equipment:%s, pos:%s" % [equip, equip.grid_pos])


## 移除卡片
func _remove_equipment_card(equip: Equipment, card_dict: Dictionary[Vector2i, EquipmentCard]) -> void:
	for pos in card_dict.keys():
		var card = card_dict[pos]
		if card.equipment == equip:
			card.queue_free()
			card_dict.erase(pos)
			DebugUtility.info("remove_equip_card", "Equipment:%s, pos:%s" % [equip, pos])

## 判断该卡片字典内是否有equip
func _get_dict_card(equip: Equipment, card_dict: Dictionary[Vector2i, EquipmentCard]) -> EquipmentCard:
	for card in card_dict.values():
		if card.equipment == equip:
			return card
	return null

## 通过卡片引用在字典中查找并移除
func _erase_card_from_dict(card: EquipmentCard, card_dict: Dictionary[Vector2i, EquipmentCard]) -> void:
	for pos in card_dict.keys():
		if card_dict[pos] == card:
			card_dict.erase(pos)
			return

## 将网格坐标通过全局坐标转换为CardContainer下的像素坐标
func _grid_to_pixel(grid_pos: Vector2i, container: Control) -> Vector2:
	var cell_local: Vector2 = Vector2(grid_pos.x * BackpackManager.CELL_SIZE, grid_pos.y * BackpackManager.CELL_SIZE)
	var cell_global: Vector2 = container.global_position + cell_local
	return cell_global - card_container.global_position


## 为所有拖拽中的卡片计算并渲染网格高亮：恢复全部ID 1 → 遍历卡片获取占用坐标 → 判断可放置/不可放置 → 覆盖写入ID 2/3
func _update_all_grid_highlights() -> void:
	_update_backpack_grid()
	_update_stage_grid()
	if _dragging_cards.is_empty():
		return

	for card in _dragging_cards:
		var centers: Array[Vector2] = card.get_occupied_global_centers()
		if centers.is_empty():
			continue

		var on_backpack: bool = false
		var on_stage: bool = false
		for point in centers:
			on_backpack = backpack_container.get_global_rect().has_point(point)
			on_stage = stage_container.get_global_rect().has_point(point)
			if on_backpack or on_stage:
				break

		if not on_backpack and not on_stage:
			continue

		var target_container: Control = backpack_container if on_backpack else stage_container
		var target_grid: Array[Array] = BackpackManager.backpack_grid if on_backpack else BackpackManager.stage_grid
		var target_tile: TileMapLayer = backpack_grid_tile if on_backpack else stage_grid_tile
		var origin_cells: Array[Vector2i] = _drag_origin_grid_cells.get(card, [])

		for center in centers:
			var grid_pos: Vector2i = BackpackManager.screen_to_grid(center, target_container.global_position)
			var gx: int = grid_pos.x
			var gy: int = grid_pos.y

			var source_id: int = 3
			if gy < 0 or gy >= target_grid.size() or gx < 0 or gx >= target_grid[gy].size():
				continue
			elif grid_pos in origin_cells:
				source_id = 2
			elif target_grid[gy][gx] != 0:
				source_id = 3
			else:
				source_id = 2

			target_tile.set_cell(grid_pos, source_id, Vector2i.ZERO)

#endregion


#region 信号回调

## 背包/闲置区内卡片拖拽释放：支持同网格移动及跨网格移动（背包↔闲置区）
func _on_card_dropped(screen_position: Vector2, equipment_card: EquipmentCard) -> void:
	var can_drop: bool = false
	var target_container: Control

	if backpack_container.get_global_rect().has_point(screen_position):
		target_container = backpack_container
		equipment_card.equipment.state = BackpackManager.GridType.PACKAGE
	elif stage_container.get_global_rect().has_point(screen_position):
		target_container = stage_container
		equipment_card.equipment.state = BackpackManager.GridType.STAGE
	else:
		equipment_card.return_to_origin()
		return

	var new_pos = BackpackManager.screen_to_grid(screen_position, target_container.global_position)
	equipment_card.equipment.grid_pos = new_pos
	can_drop = BackpackManager.move_to_grid(equipment_card.equipment, equipment_card.origin_equipment)

	if not can_drop:
		equipment_card.return_to_origin()
	# 移动成功时无需手动更新card字典，_sync_cards已通过stats_recalculated信号重建全部卡片

## 属性重算时刷新全部显示
func _on_equip_changed() -> void:
	_update_view()
	if not _dragging_cards.is_empty():
		_update_all_grid_highlights()

## 卡片拖拽状态变化回调：开始拖拽时记录原始占用网格坐标，结束拖拽时恢复网格
func _on_card_drag_state_changed(is_dragging: bool, card: EquipmentCard) -> void:
	if is_dragging:
		var origin_cells: Array[Vector2i] = []
		if card.origin_equipment:
			var origin_shape: Array[Array] = card.origin_equipment.shape
			var origin_pos: Vector2i = card.origin_equipment.grid_pos
			for y in origin_shape.size():
				for x in origin_shape[y].size():
					if origin_shape[y][x] == 1:
						origin_cells.append(Vector2i(origin_pos.x + x, origin_pos.y + y))
		_drag_origin_grid_cells[card] = origin_cells
		if not _dragging_cards.has(card):
			_dragging_cards.append(card)
	else:
		_dragging_cards.erase(card)
		if _drag_origin_grid_cells.has(card):
			_drag_origin_grid_cells.erase(card)
		if _dragging_cards.is_empty():
			_update_backpack_grid()
			_update_stage_grid()

#endregion

#region 公开功能

## 注册外部卡片的拖拽状态变化（如商店卡片），使Package能同步更新网格高亮
func register_dragging_card(card: EquipmentCard) -> void:
	if card.drag_state_changed.is_connected(_on_card_drag_state_changed):
		return
	card.drag_state_changed.connect(_on_card_drag_state_changed.bind(card))

#endregion
