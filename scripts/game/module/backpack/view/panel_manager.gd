class_name PanelManager
extends Control
## 商店场景：管理商店刷新、购买和关卡推进

@onready var shop: Shop = $Shop
@onready var package: Package = $Package
@onready var map: Control = $Map
@onready var forge: Forge = $Forge
@onready var panel_animation: AnimationPlayer = $PanelAnimation

var _dragging_cards: Array[EquipmentCard] = []
var _drag_origin_grid_cells: Dictionary = {}

func _ready() -> void:
	_update_map()
	_regist_card_signal()
	show_map()

	package.add_equipment_card.connect(_on_add_equipment_card)
	shop.exit_button.pressed.connect(_on_shop_exit_button_pressed)
	forge.add_equipment_card.connect(_on_add_equipment_card)
	forge.exit_button.pressed.connect(_on_forge_exit_button_pressed)

func _process(_delta: float) -> void:
	if _dragging_cards.is_empty():
		return
	_update_all_grid_highlights()

#region 公开功能

## 打开商店
func show_shop() -> void:
	shop.set_equipment_pool()

	if panel_animation.is_playing():
		await panel_animation.animation_finished
	panel_animation.play("show_shop")

## 关闭商店
func hide_shop() -> void:
	if panel_animation.is_playing():
		await panel_animation.animation_finished
	panel_animation.play("hide_shop")

## 显示地图
func show_map() -> void:
	var map_scene: Map = map.get_child(0) as Map
	if map_scene == null:
		return
	map_scene.update_map_nodes()

	if panel_animation.is_playing():
		await panel_animation.animation_finished
	panel_animation.play("show_map")
	
	map_scene.scroll_to_current_map_node_button()

## 关闭地图
func hide_map() -> void:
	var map_scene: Map = map.get_child(0) as Map
	if map_scene == null:
		return
	map_scene.scroll_to_top()

	if panel_animation.is_playing():
		await panel_animation.animation_finished
	panel_animation.play("hide_map")

## 显示背包
func show_package() -> void:
	if panel_animation.is_playing():
		await panel_animation.animation_finished
	panel_animation.play("show_package")

## 关闭背包
func hide_package() -> void:
	if panel_animation.is_playing():
		await panel_animation.animation_finished
	panel_animation.play("hide_package")

## 显示锻造
func show_forge() -> void:
	if panel_animation.is_playing():
		await panel_animation.animation_finished
	panel_animation.play("show_forge")

## 关闭锻造
func hide_forge() -> void:
	if panel_animation.is_playing():
		await panel_animation.animation_finished
	panel_animation.play("hide_forge")

#endregion

#region 内部方法

## 初始化刷新所有网格
func _update_all_grid():
	package._update_backpack_grid()
	package._update_stage_grid()
	forge._update_table_grid()


## 刷新地图界面信息
func _update_map():
	for child_map in map.get_children():
		map.remove_child(child_map)
		child_map.queue_free()

	var map_scene: PackedScene = load("res://scene/map/map_%s.tscn" % MapManager.current_map_id)
	var cur_map: Map = map_scene.instantiate() as Map
	map.add_child(cur_map)
	

## 给所有卡片注册对应拖拽与放下事件
func _regist_card_signal():
	## 商店卡片
	for card in shop.get_cards():
		if not card.drag_dropped.is_connected(_on_equipment_dropped):
			card.drag_dropped.connect(_on_equipment_dropped.bind(card))
		if not card.drag_state_changed.is_connected(_on_card_drag_state_changed):
			card.drag_state_changed.connect(_on_card_drag_state_changed.bind(card))
	
	## 背包装备区卡片
	for card in package.backpack_cards.values():
		if not card.drag_dropped.is_connected(_on_equipment_dropped):
			card.drag_dropped.connect(_on_equipment_dropped.bind(card))
		if not card.drag_state_changed.is_connected(_on_card_drag_state_changed):
			card.drag_state_changed.connect(_on_card_drag_state_changed.bind(card))

	## 背包暂存区卡片
	for card in package.stage_cards.values():
		if not card.drag_dropped.is_connected(_on_equipment_dropped):
			card.drag_dropped.connect(_on_equipment_dropped.bind(card))
		if not card.drag_state_changed.is_connected(_on_card_drag_state_changed):
			card.drag_state_changed.connect(_on_card_drag_state_changed.bind(card))
	
	## 锻造台卡片
	for card in forge.table_cards.values():
		if not card.drag_dropped.is_connected(_on_equipment_dropped):
			card.drag_dropped.connect(_on_equipment_dropped.bind(card))
		if not card.drag_state_changed.is_connected(_on_card_drag_state_changed):
			card.drag_state_changed.connect(_on_card_drag_state_changed.bind(card))
	
	## 锻造结果卡片
	var card = forge.result_equipment_card
	if not card.drag_dropped.is_connected(_on_equipment_dropped):
		card.drag_dropped.connect(_on_equipment_dropped.bind(card))
	if not card.drag_state_changed.is_connected(_on_card_drag_state_changed):
		card.drag_state_changed.connect(_on_card_drag_state_changed.bind(card))

func _update_all_grid_highlights() -> void:
	_update_all_grid()
	if _dragging_cards.is_empty():
		return

	for card in _dragging_cards:
		var centers: Array[Vector2] = card.get_occupied_global_centers()
		if centers.is_empty():
			continue

		var target_container: Control = null
		var target_tile: TileMapLayer = null
		var target_grid: Array[Array] = []
		for point in centers:
			if package.backpack_container.get_global_rect().has_point(point):
				target_container = package.backpack_container
				target_tile = package.backpack_grid_tile
				target_grid = BackpackManager.backpack_grid
			elif package.stage_container.get_global_rect().has_point(point):
				target_container = package.stage_container
				target_tile = package.stage_grid_tile
				target_grid = BackpackManager.stage_grid
			elif forge.forge_table_grid.get_global_rect().has_point(point):
				target_container = forge.forge_table_grid
				target_tile = forge.forge_table_grid_tile
				target_grid = BackpackManager.forge_grid
			else:
				continue
		if target_container == null:
			continue

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
## 添加装备卡片
func _on_add_equipment_card(card: EquipmentCard):
	if not card.drag_dropped.is_connected(_on_equipment_dropped):
		card.drag_dropped.connect(_on_equipment_dropped.bind(card))
	if not card.drag_state_changed.is_connected(_on_card_drag_state_changed):
		card.drag_state_changed.connect(_on_card_drag_state_changed.bind(card))

## 装备拖拽放置处理：判断是否落在背包网格内，执行放置或归位
func _on_equipment_dropped(screen_position: Vector2, equipment_card: EquipmentCard) -> void:
	var origin_grid_type: BackpackManager.GridType = equipment_card.origin_equipment.state
	if origin_grid_type == BackpackManager.GridType.SHOP:
		if GameState.gold < equipment_card.equipment.price:
			equipment_card.return_to_origin()
			return

	# 判断背包对应区域是否可放置对应装备
	var can_place: bool = false
	var target_container: Control
	var new_pos: Vector2i = Vector2i(-1, -1)
	if package.backpack_container.get_global_rect().has_point(screen_position):
		target_container = package.backpack_container
		equipment_card.equipment.state = BackpackManager.GridType.PACKAGE
	elif package.stage_container.get_global_rect().has_point(screen_position):
		target_container = package.stage_container
		equipment_card.equipment.state = BackpackManager.GridType.STAGE
	elif forge.forge_table_grid.get_global_rect().has_point(screen_position):
		target_container = forge.forge_table_grid
		equipment_card.equipment.state = BackpackManager.GridType.FORGE_TABLE
	else:
		equipment_card.return_to_origin()
		return
	new_pos = BackpackManager.screen_to_grid(screen_position, target_container.global_position)
	equipment_card.equipment.grid_pos = new_pos

	# 实例化卡片
	var target_grid_type: BackpackManager.GridType = equipment_card.equipment.state
	if origin_grid_type == BackpackManager.GridType.SHOP and (target_grid_type == BackpackManager.GridType.PACKAGE or target_grid_type == BackpackManager.GridType.STAGE):
		var new_equipment = equipment_card.equipment.copy()
		can_place = BackpackManager.add_to_equip_grid(new_equipment, new_pos)
		if can_place and GameState.gold >= equipment_card.equipment.price:
			GameState.gold -= equipment_card.equipment.price
			equipment_card.visible = false
		equipment_card.return_to_origin()
	elif origin_grid_type == BackpackManager.GridType.FORGE_REWARD and (target_grid_type == BackpackManager.GridType.PACKAGE or target_grid_type == BackpackManager.GridType.STAGE):
		var new_equipment = equipment_card.equipment.copy()
		can_place = BackpackManager.add_to_equip_grid(new_equipment, new_pos)
		if can_place:
			equipment_card.visible = false
		equipment_card.return_to_origin()
	elif origin_grid_type == BackpackManager.GridType.PACKAGE or origin_grid_type == BackpackManager.GridType.STAGE:
		if target_grid_type == BackpackManager.GridType.FORGE_TABLE:
			var new_equipment = equipment_card.equipment.copy()
			new_equipment.preview_equipment = equipment_card.origin_equipment
			equipment_card.equipment.copy_equipment(equipment_card.origin_equipment)
			can_place = BackpackManager.add_to_equip_grid(new_equipment, new_pos)
			if can_place:
				equipment_card.set_preview_modulate(true)
			equipment_card.return_to_origin()
		elif target_grid_type == BackpackManager.GridType.PACKAGE or target_grid_type == BackpackManager.GridType.STAGE:
			can_place = BackpackManager.move_to_grid(equipment_card.equipment, equipment_card.origin_equipment)
			if not can_place:
				equipment_card.return_to_origin()
	elif origin_grid_type == BackpackManager.GridType.FORGE_TABLE:
		if target_grid_type == BackpackManager.GridType.PACKAGE or target_grid_type == BackpackManager.GridType.STAGE:
			var preview_equipment: Equipment = equipment_card.equipment.preview_equipment
			can_place = BackpackManager.remove_equipment(equipment_card.origin_equipment)
			if can_place:
				var card: EquipmentCard
				if preview_equipment.state == BackpackManager.GridType.PACKAGE:
					card = package.backpack_cards[preview_equipment.grid_pos]
				elif preview_equipment.state == BackpackManager.GridType.STAGE:
					card = package.stage_cards[preview_equipment.grid_pos]
				card.set_preview_modulate(false)
			else:
				equipment_card.return_to_origin()
		elif target_grid_type == BackpackManager.GridType.FORGE_TABLE:
			can_place = BackpackManager.move_to_grid(equipment_card.equipment, equipment_card.origin_equipment)
			if not can_place:
				equipment_card.return_to_origin()
			

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
			_update_all_grid()


## 关闭隐藏商店界面
func _on_shop_exit_button_pressed():
	hide_shop()
	show_map()


## 关闭隐藏锻造界面
func _on_forge_exit_button_pressed():
	for card: EquipmentCard in forge.table_cards.values():
		var preview_card: EquipmentCard = null
		var preview_equipment: Equipment = card.equipment.preview_equipment
		if preview_equipment.state == BackpackManager.GridType.PACKAGE:
			preview_card = package.backpack_cards[preview_equipment.grid_pos]
		elif preview_equipment.state == BackpackManager.GridType.STAGE:
			preview_card = package.stage_cards[preview_equipment.grid_pos]
		preview_card.set_preview_modulate(false)
		BackpackManager.remove_equipment(card.equipment)
	forge.show_merge_result_card()
	hide_forge()
	show_map()


#endregion
