class_name Package
extends Control
## 背包网格UI：根据BackpackManager数据刷新网格瓦片和装备卡片显示

const CARD_SCENE: String = "res://scene/shop/equipment_card.tscn"

@onready var _backpack_grid_tile: TileMapLayer = $PakageGrid/GridTile
@onready var _stage_grid_tile: TileMapLayer = $StageGrid/GridTile
@onready var _backpack_container: Control = $PakageGrid
@onready var _stage_container: Control = $StageGrid
@onready var _card_container: Control = $CardContainer

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
	_backpack_grid_tile.clear()
	var grid: Array[Array] = BackpackManager.backpack_grid
	for y in grid.size():
		for x in grid[y].size():
			if grid[y][x] != -1:
				_backpack_grid_tile.set_cell(Vector2i(x, y), 1, Vector2i.ZERO)

## 根据stage_grid数据刷新闲置区网格瓦片
func _update_stage_grid() -> void:
	_stage_grid_tile.clear()
	var grid: Array[Array] = BackpackManager.stage_grid
	for y in grid.size():
		for x in grid[y].size():
			if grid[y][x] != -1:
				_stage_grid_tile.set_cell(Vector2i(x, y), 1, Vector2i.ZERO)

## 同步背包装备卡片：创建新卡片、移除已删除装备的卡片、更新位置
func _sync_backpack_cards() -> void:
	_sync_cards(BackpackManager.backpack_equip, _backpack_cards, _backpack_container)


## 同步闲置区装备卡片：创建新卡片、移除已删除装备的卡片、更新位置
func _sync_stage_cards() -> void:
	_sync_cards(BackpackManager.stage_equip, _stage_cards, _stage_container)


func _sync_cards(equip_dict: Dictionary[Vector2i, Equipment], card_dict: Dictionary[Vector2i, EquipmentCard], container: Control) -> void:
	for pos in equip_dict.keys():
		var equip: Equipment = equip_dict[pos]
		if not card_dict.has(pos):
			## 判断当前装备网格是否有该装备的数据
			if _get_dict_card(equip, card_dict) != null:
				_move_equipment_card(equip, card_dict, container)
			## 判断当前装备是否是从其他网格移动过来的
			else:
				var other_dict: Dictionary = _stage_cards if card_dict == _backpack_cards else _backpack_cards
				var card: EquipmentCard = _get_dict_card(equip, other_dict)
				if card != null:
					_erase_card_from_dict(card, other_dict)
					card.position = _grid_to_pixel(equip.grid_pos, container) - card.get_rotate_offset()
					card_dict[equip.grid_pos] = card
				else:
					_add_equipment_card(equip, card_dict, container)
		else:
			## 每次刷新修正卡片位置
			var card = card_dict[pos]
			card.position = _grid_to_pixel(equip.grid_pos, container) - card.get_rotate_offset()


## 移动装备卡片位置
func _move_equipment_card(equip: Equipment, card_dict: Dictionary[Vector2i, EquipmentCard], container: Control) -> void:
	for pos in card_dict.keys():
		var card = card_dict[pos]
		if equip == card.equipment and card.equipment.grid_pos != pos:
			card_dict.erase(pos)
			card.position = _grid_to_pixel(equip.grid_pos, container) - card.get_rotate_offset()
			card_dict[equip.grid_pos] = card
			DebugUtility.info("move_equip_card", "%s->%s" % [pos, equip.grid_pos])


## 添加卡片
func _add_equipment_card(equip: Equipment, card_dict: Dictionary[Vector2i, EquipmentCard], container: Control) -> void:
	var card_scene: PackedScene = load(CARD_SCENE)
	var card: EquipmentCard = card_scene.instantiate()
	_card_container.add_child(card)
	card.setup_by_equipment(equip)
	card.position = _grid_to_pixel(equip.grid_pos, container) - card.get_rotate_offset()
	card.drag_dropped.connect(_on_card_dropped)
	card.drag_state_changed.connect(_on_card_drag_state_changed.bind(card))
	card_dict[equip.grid_pos] = card
	DebugUtility.info("add_equip_card", "%s"%card)


## 移除卡片
func _remove_equipment_card(equip: Equipment, card_dict: Dictionary[Vector2i, EquipmentCard]) -> void:
	var card: EquipmentCard = card_dict[equip.grid_pos]
	card.queue_free()
	if card_dict.erase(equip.grid_pos):
		DebugUtility.info("remove_equip_card", "%s"%card)

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
	return cell_global - _card_container.global_position

## 移动被拒绝：卡片归位
func _reject_card_move(equip: Equipment) -> void:
	var is_backpack: bool = equip.state == Equipment.EQUIPMENT_STATE.BACKPACK
	var card_dict: Dictionary = _backpack_cards if is_backpack else _stage_cards
	var card: EquipmentCard = card_dict.get(equip.grid_pos)
	if card:
		card.return_to_origin()


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
			on_backpack = _backpack_container.get_global_rect().has_point(point)
			on_stage = _stage_container.get_global_rect().has_point(point)
			if on_backpack or on_stage:
				break
		
		if not on_backpack and not on_stage:
			continue

		var target_container: Control = _backpack_container if on_backpack else _stage_container
		var target_grid: Array[Array] = BackpackManager.backpack_grid if on_backpack else BackpackManager.stage_grid
		var target_tile: TileMapLayer = _backpack_grid_tile if on_backpack else _stage_grid_tile
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
func _on_card_dropped(equip: Equipment, screen_position: Vector2) -> void:
	if equip.state == Equipment.EQUIPMENT_STATE.SHOP:
		return

	var is_backpack: bool = equip.state == Equipment.EQUIPMENT_STATE.BACKPACK
	var old_pos: Vector2i = equip.grid_pos

	# 判断目标网格
	var on_backpack: bool = _backpack_container.get_global_rect().has_point(screen_position)
	var on_stage: bool = _stage_container.get_global_rect().has_point(screen_position)
	if not on_backpack and not on_stage:
		_reject_card_move(equip)
		return

	var to_backpack: bool = on_backpack
	var target_container: Control = _backpack_container if to_backpack else _stage_container
	var target_grid: Array[Array] = BackpackManager.backpack_grid if to_backpack else BackpackManager.stage_grid
	var new_pos: Vector2i = BackpackManager.screen_to_grid(screen_position, target_container.global_position)

	# 边界检查
	if new_pos.x < 0 or new_pos.y < 0 or new_pos.y >= target_grid.size() or new_pos.x >= target_grid[0].size():
		_reject_card_move(equip)
		return

	# 同网格同位置且旋转未变，归位
	var card_dict: Dictionary = _backpack_cards if is_backpack else _stage_cards
	var card: EquipmentCard = _get_dict_card(equip, card_dict)
	if card == null:
		_reject_card_move(equip)
		return

	var rotated: bool = card.get_origin_rotate_times() != equip.rotate_times
	if is_backpack == to_backpack and new_pos == old_pos and not rotated:
		_reject_card_move(equip)
		return

	var moved: bool
	var origin_shape: Array = card._origin_equipment.shape
	if is_backpack == to_backpack:
		moved = BackpackManager.move_in_backpack(equip, new_pos, rotated, origin_shape) if is_backpack else BackpackManager.move_in_stage(equip, new_pos, rotated, origin_shape)
	else:
		moved = BackpackManager.move_to_grid(equip, new_pos, to_backpack, origin_shape)

	if not moved:
		_reject_card_move(equip)
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
		if card._origin_equipment:
			var origin_shape: Array[Array] = card._origin_equipment.shape
			var origin_pos: Vector2i = card._origin_equipment.grid_pos
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