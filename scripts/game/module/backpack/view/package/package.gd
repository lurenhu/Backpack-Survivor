class_name Package
extends Control
## 背包网格UI：根据BackpackManager数据刷新网格瓦片和装备卡片显示

const CARD_SCENE: PackedScene = preload("res://scene/shop/equipment_card.tscn")
const PACKAGE_LABEL_SCENE: PackedScene = preload("res://scene/shop/package_label.tscn")

@onready var backpack_grid_tile: TileMapLayer = $PakageGrid/GridTile
@onready var stage_grid_tile: TileMapLayer = $StageGrid/GridTile
@onready var backpack_container: Control = $PakageGrid
@onready var stage_container: Control = $StageGrid
@onready var card_container: Control = $CardContainer
@onready var gold_label: Label = $Coin/Label

signal add_equipment_card(card: EquipmentCard)

# 背包网格装备卡片字典vector2i -> equipmentcard
var backpack_cards: Dictionary[Vector2i, EquipmentCard] = {}
# 闲置区网格装备卡片字典vector2i -> equipmentcard
var stage_cards: Dictionary[Vector2i, EquipmentCard] = {}
var _grid_purchase_label: PackageLabel = null
var _hovered_purchase_grid: Vector2i = Vector2i(-1, -1)

## 就绪时连接信号并初始化显示
func _ready() -> void:
	BackpackManager.equip_changed.connect(_update_view)
	BackpackManager.forge_changed.connect(_update_view)
	BackpackManager.grid_purchase_state_changed.connect(_on_grid_purchase_state_changed)
	BackpackManager.gold_changed.connect(_on_gold_changed)
	_update_view()
	_on_gold_changed(BackpackManager.gold)
	set_process_input(true)


func _input(event: InputEvent) -> void:
	if not BackpackManager.is_grid_purchase_mode:
		return
	if event is InputEventMouseMotion:
		_update_grid_purchase_hover((event as InputEventMouseMotion).position)
		return
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if not backpack_container.get_global_rect().has_point(mouse_event.position):
		return

	var local_position := backpack_grid_tile.to_local(mouse_event.position)
	var grid_pos := backpack_grid_tile.local_to_map(local_position)
	if BackpackManager.purchase_grid(grid_pos):
		if is_instance_valid(_grid_purchase_label) and _hovered_purchase_grid == grid_pos:
			var purchased_label: PackageLabel = _grid_purchase_label
			_grid_purchase_label = null
			_hovered_purchase_grid = Vector2i(-1, -1)
			purchased_label.play_purchase_animation()
		get_viewport().set_input_as_handled()


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
	var purchasable_cells: Array[Vector2i] = []
	if BackpackManager.is_grid_purchase_mode:
		purchasable_cells = BackpackManager.get_purchasable_grid_cells()
	for y in grid.size():
		for x in grid[y].size():
			var grid_pos := Vector2i(x, y)
			if grid_pos in purchasable_cells:
				backpack_grid_tile.set_cell(grid_pos, 4, Vector2i.ZERO)
			elif grid[y][x] != -1:
				backpack_grid_tile.set_cell(grid_pos, 1, Vector2i.ZERO)
			else:
				backpack_grid_tile.set_cell(grid_pos, 0, Vector2i.ZERO)


## 根据鼠标位置显示或隐藏可购买网格的价格标签
func _update_grid_purchase_hover(mouse_global_position: Vector2) -> void:
	if not BackpackManager.is_grid_purchase_mode:
		_clear_grid_purchase_label()
		return
	if not backpack_container.get_global_rect().has_point(mouse_global_position):
		_clear_grid_purchase_label()
		return

	var local_position := backpack_grid_tile.to_local(mouse_global_position)
	var grid_pos := backpack_grid_tile.local_to_map(local_position)
	if grid_pos not in BackpackManager.get_purchasable_grid_cells():
		_clear_grid_purchase_label()
		return
	if is_instance_valid(_grid_purchase_label) and _hovered_purchase_grid == grid_pos:
		_grid_purchase_label.call("show_cost", BackpackManager.grid_cost)
		return

	_clear_grid_purchase_label()
	var label := PACKAGE_LABEL_SCENE.instantiate() as PackageLabel
	add_child(label)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.show_cost(BackpackManager.grid_cost)
	label.reset_size()
	var cell_center := backpack_grid_tile.to_global(backpack_grid_tile.map_to_local(grid_pos))
	label.global_position = cell_center - label.size / 2.0
	_grid_purchase_label = label
	_hovered_purchase_grid = grid_pos


func _clear_grid_purchase_label() -> void:
	if is_instance_valid(_grid_purchase_label):
		_grid_purchase_label.queue_free()
	_grid_purchase_label = null
	_hovered_purchase_grid = Vector2i(-1, -1)

## 根据stage_grid数据刷新闲置区网格瓦片
func _update_stage_grid() -> void:
	stage_grid_tile.clear()
	var grid: Array[Array] = BackpackManager.stage_grid
	for y in grid.size():
		for x in grid[y].size():
			if grid[y][x] != -1:
				stage_grid_tile.set_cell(Vector2i(x, y), 1, Vector2i.ZERO)
			else:
				stage_grid_tile.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)


## 同步背包装备卡片：创建新卡片、移除已删除装备的卡片、更新位置
func _sync_backpack_cards() -> void:
	_sync_cards(BackpackManager.backpack_equip, backpack_cards, backpack_container)


## 同步闲置区装备卡片：创建新卡片、移除已删除装备的卡片、更新位置
func _sync_stage_cards() -> void:
	_sync_cards(BackpackManager.stage_equip, stage_cards, stage_container)


func _sync_cards(equip_dict: Dictionary[Vector2i, Equipment], card_dict: Dictionary[Vector2i, EquipmentCard], grid_container: Control) -> void:
	var existing: Dictionary[int, EquipmentCard] = {}
	for card in card_dict.values():
		existing[card.equipment.instance_id] = card
	card_dict.clear()
	for equip in equip_dict.values():
		var card: EquipmentCard = existing.get(equip.instance_id)
		if card == null:
			card = CARD_SCENE.instantiate()
			card_container.add_child(card)
			card.setup_by_equipment(equip)
			add_equipment_card.emit(card)
		else:
			existing.erase(equip.instance_id)
		if not card.is_interacting():
			card.setup_by_equipment(equip)
			card.position = BackpackManager.grid_to_pixel(equip.grid_pos, grid_container, card_container) - card.get_rotate_offset()
		card.set_preview_modulate(BackpackManager.is_material_selected(equip.instance_id))
		card_dict[equip.grid_pos] = card
	for card in existing.values():
		card.hide()
		card.queue_free()

#endregion


#region 信号回调

func _on_gold_changed(current_gold: int) -> void:
	gold_label.text = str(current_gold)


func _on_grid_purchase_state_changed() -> void:
	_update_backpack_grid()
	if not BackpackManager.is_grid_purchase_mode:
		_clear_grid_purchase_label()

#endregion


#region 公开功能


#endregion
