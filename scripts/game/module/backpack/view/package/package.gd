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
var backpack_cards: Dictionary[Vector2i, EquipmentCard] = {}
# 闲置区网格装备卡片字典vector2i -> equipmentcard
var stage_cards: Dictionary[Vector2i, EquipmentCard] = {}

## 就绪时连接信号并初始化显示
func _ready() -> void:
	BackpackManager.equip_changed.connect(_update_view)
	_update_view()


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
			else:
				backpack_grid_tile.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)

## 根据stage_grid数据刷新闲置区网格瓦片
func _update_stage_grid() -> void:
	stage_grid_tile.clear()
	var grid: Array[Array] = BackpackManager.stage_grid
	for y in grid.size():
		for x in grid[y].size():
			if grid[y][x] != -1:
				stage_grid_tile.set_cell(Vector2i(x, y), 1, Vector2i.ZERO)
			else:
				backpack_grid_tile.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)


## 同步背包装备卡片：创建新卡片、移除已删除装备的卡片、更新位置
func _sync_backpack_cards() -> void:
	_sync_cards(BackpackManager.backpack_equip, backpack_cards, backpack_container)


## 同步闲置区装备卡片：创建新卡片、移除已删除装备的卡片、更新位置
func _sync_stage_cards() -> void:
	_sync_cards(BackpackManager.stage_equip, stage_cards, stage_container)


func _sync_cards(equip_dict: Dictionary[Vector2i, Equipment], card_dict: Dictionary[Vector2i, EquipmentCard], grid_container: Control) -> void:
	# 添加equip_dict中存在但card_dict中不存在的装备卡片
	DebugUtility.info("current_container", "%s" % grid_container.name)
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
		card.position = BackpackManager.grid_to_pixel(card.equipment.grid_pos, grid_container, card_container) - card.get_rotate_offset()


## 添加卡片
func _add_equipment_card(equip: Equipment, card_dict: Dictionary[Vector2i, EquipmentCard]) -> void:
	var card: EquipmentCard = CARD_SCENE.instantiate()
	card_container.add_child(card)
	card.setup_by_equipment(equip)
	card_dict[equip.grid_pos] = card
	BackpackManager.add_equipment_card.emit(card)
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

#endregion


#region 信号回调

#endregion


#region 公开功能


#endregion
