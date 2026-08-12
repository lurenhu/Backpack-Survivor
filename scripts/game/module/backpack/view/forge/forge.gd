class_name Forge
extends Control
## 锻造界面：从背包拖入材料装备，合成目标装备

const CARD_SCENE: PackedScene = preload("res://scene/shop/equipment_card.tscn")

@onready var result_name: Label = $ForgeResultCard/Label
@onready var result_equipment_card: EquipmentCard = $ForgeResultCard/CenterContainer/EquipmentCard
@onready var forge_table_grid_tile: TileMapLayer = $ForgeTableGrid/GridTile
@onready var forge_table_grid: Control = $ForgeTableGrid
@onready var forge_button: Button = $ForgeButton
@onready var exit_button: Button = $ExitButton
@onready var card_container: Control = $CardContainer


# 材料卡片: {Vector2i: EquipmentCard}
var table_cards: Dictionary[Vector2i, EquipmentCard] = {}

func _ready() -> void:
	result_equipment_card.visible = false
	BackpackManager.equip_changed.connect(_update_view)
	_update_view()

	forge_button.pressed.connect(_on_forge_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)

#region 公开方法


#endregion


#region 内部功能

## 初始化界面
func _update_view():
	_update_table_grid()
	_sync_cards(BackpackManager.forge_equip, table_cards, forge_table_grid)


## 刷新结果网格显示
func _update_table_grid() -> void:
	forge_table_grid_tile.clear()
	var grid: Array[Array] = BackpackManager.forge_grid
	for y in grid.size():
		for x in grid[y].size():
			if grid[y][x] != -1:
				forge_table_grid_tile.set_cell(Vector2i(x, y), 1, Vector2i.ZERO)


## 同步卡片信息
func _sync_cards(equip_dict: Dictionary[Vector2i, Equipment], card_dict: Dictionary[Vector2i, EquipmentCard], grid_container: Control) -> void:
	# 添加equip_dict中存在但card_dict中不存在的装备卡片
	DebugUtility.info("current_container", "%s" % grid_container.name)
	for equip in equip_dict.values():
		if _get_dict_card(equip, card_dict) == null:
			_add_equipment_card(equip)

	# 删除card_dict中存在但equip_dict中不存在的装备卡片
	var to_remove: Array[Equipment] = []
	for card in card_dict.values():
		if not equip_dict.values().has(card.equipment):
			to_remove.append(card.equipment)
	for equip in to_remove:
		_remove_equipment_card(equip)
	
	# 修正key值与grid_pos不匹配的卡片，同步position坐标
	for card_pos in card_dict.keys():
		var card: EquipmentCard = card_dict[card_pos]
		if card_pos != card.equipment.grid_pos:
			card_dict.erase(card_pos)
			card_dict[card.equipment.grid_pos] = card
			#DebugUtility.info("update_equip_card", "Equipment:%s, pos:%s" % [card.equipment, card.equipment.grid_pos])
		card.position = BackpackManager.grid_to_pixel(card.equipment.grid_pos, grid_container, card_container) - card.get_rotate_offset()


## 添加装备卡片
func _add_equipment_card(equip: Equipment):
	var card: EquipmentCard = CARD_SCENE.instantiate()
	card_container.add_child(card)
	card.setup_by_equipment(equip)
	table_cards[equip.grid_pos] = card
	BackpackManager.add_equipment_card.emit(card)
	DebugUtility.info("add_equip_card", "Equipment:%s, pos:%s" % [equip, equip.grid_pos])


## 移除装备卡片
func _remove_equipment_card(equip: Equipment):
	for pos in table_cards.keys():
		var card = table_cards[pos]
		if card.equipment == equip:
			card.queue_free()
			table_cards.erase(pos)
			DebugUtility.info("remove_equip_card", "Equipment:%s, pos:%s" % [equip, pos])


## 判断该卡片字典内是否有equip
func _get_dict_card(equip: Equipment, card_dict: Dictionary[Vector2i, EquipmentCard]) -> EquipmentCard:
	for card in card_dict.values():
		if card.equipment == equip:
			return card
	return null

## 获取当前锻造台内的所有装备id
func _get_material_ids() -> Array[int]:
	var result: Array[int] = []
	for card: EquipmentCard in table_cards.values():
		result.append(card.equipment.id)
	return result

## 通过值寻找键值
func _find_keys_by_value(dict: Dictionary, target: Array[int]) -> int:
	var target_sorted := PackedInt32Array(target)
	target_sorted.sort()
	for key in dict:
		var forge_data: EquipmentForgeData = dict[key]
		var materials := PackedInt32Array(forge_data.material_ids)
		materials.sort()
		if materials == target_sorted:
			return key
	return 0

#endregion

#region 信号回调

## 点按锻造按钮
func _on_forge_button_pressed():
	var equipment_ids = _get_material_ids()
	var result_id = _find_keys_by_value(GameConfig.forges, equipment_ids)
	if result_id == 0:
		return

	for card in table_cards.values():
		BackpackManager.remove_equipment(card.equipment)

	result_equipment_card.visible = true
	result_equipment_card.setup(result_id, BackpackManager.GridType.FORGE_REWARD)
	result_name.text = result_equipment_card.equipment.name


## 点按退出按钮
func _on_exit_button_pressed():
	pass

#endregion
