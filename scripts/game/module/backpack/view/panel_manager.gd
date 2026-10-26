class_name PanelManager
extends Control
## 展示业务状态，转发背包操作和节点退出请求。

@onready var shop: Shop = $Shop
@onready var package: Package = $Package
@onready var map: Control = $Map
@onready var forge: Forge = $Forge
@onready var panel_animation: AnimationPlayer = $PanelAnimation

var _shown_panel: StringName = &""
var _requested_panel: StringName = &""
var _switching_panels: bool = false
var _input_blocker: Control

var is_switching_panels: bool:
	get: return _switching_panels

var _dragging_cards: Array[EquipmentCard] = []
var _drag_origin_grid_cells: Dictionary = {}

func _ready() -> void:
	_update_map()
	_regist_card_signal()
	# 初始位置只重置一次，之后由 hide/show 动画接续控制。
	panel_animation.play("RESET")
	panel_animation.advance(0)
	panel_animation.stop()
	for control in [map, shop, forge, package]:
		control.hide()
	_input_blocker = Control.new()
	_input_blocker.name = "TransitionInputBlocker"
	_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_input_blocker)
	_input_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_input_blocker.hide()
	present_phase(GameState.phase)

	package.add_equipment_card.connect(_on_add_equipment_card)
	shop.exit_button.pressed.connect(_on_shop_exit_button_pressed)
	forge.add_equipment_card.connect(_on_add_equipment_card)
	forge.exit_button.pressed.connect(_on_forge_exit_button_pressed)

func _process(_delta: float) -> void:
	if _dragging_cards.is_empty():
		return
	_update_all_grid_highlights()

#region 公开功能

## 一个切换任务顺序播放动画；等待期间的新请求只更新最终目标。
func present_phase(phase: RunState.Phase) -> void:
	var target: StringName = &""
	match phase:
		RunState.Phase.MAP: target = &"map"
		RunState.Phase.SHOP: target = &"shop"
		RunState.Phase.FORGE: target = &"forge"
	_requested_panel = target
	if not _switching_panels and _shown_panel != _requested_panel:
		_switch_panels()


func _switch_panels() -> void:
	_switching_panels = true
	_input_blocker.show()
	while _shown_panel != _requested_panel:
		if not _shown_panel.is_empty():
			if _shown_panel == &"map":
				(map.get_child(0) as Map).scroll_to_top()
			panel_animation.play("hide_" + _shown_panel)
			await panel_animation.animation_finished
			_shown_panel = &""
			# hide 结束后重新读取目标，过期的 show 请求不会再播放。
			continue
		_shown_panel = _requested_panel
		match _shown_panel:
			&"map":
				var map_scene := map.get_child(0) as Map
				map_scene.update_map_nodes()
				map_scene.scroll_to_current_map_node_button()
			&"shop":
				shop.update_view()
		panel_animation.play("show_" + _shown_panel)
		await panel_animation.animation_finished
	_switching_panels = false
	_input_blocker.hide()

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

	var map_scene: PackedScene = load(MapManager.get_map_scene_path(MapManager.current_map_id))
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

	for card in _dragging_cards.duplicate():
		if not is_instance_valid(card) or card.is_queued_for_deletion():
			_dragging_cards.erase(card)
			continue
		var centers: Array[Vector2] = card.get_occupied_global_centers()
		if centers.is_empty():
			continue

		var target_container: Control = null
		var target_tile: TileMapLayer = null
		var target_grid: Array[Array] = []
		var target_type: int = BackpackManager.GridType.NONE
		for point in centers:
			if package.backpack_container.get_global_rect().has_point(point):
				target_container = package.backpack_container
				target_tile = package.backpack_grid_tile
				target_grid = BackpackManager.backpack_grid
				target_type = BackpackManager.GridType.PACKAGE
			elif package.stage_container.get_global_rect().has_point(point):
				target_container = package.stage_container
				target_tile = package.stage_grid_tile
				target_grid = BackpackManager.stage_grid
				target_type = BackpackManager.GridType.STAGE
			elif forge.forge_table_grid.get_global_rect().has_point(point):
				target_container = forge.forge_table_grid
				target_tile = forge.forge_table_grid_tile
				target_grid = BackpackManager.forge_grid
				target_type = BackpackManager.GridType.FORGE_TABLE
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
			elif card.origin_equipment.state == target_type and grid_pos in origin_cells:
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
func _on_equipment_dropped(screen_position: Vector2, card: EquipmentCard) -> void:
	var source := card.origin_equipment
	var rotation := card.equipment.rotate_times
	card.finish_drag()
	_dragging_cards.erase(card)
	_drag_origin_grid_cells.erase(card)
	var area: int = BackpackManager.GridType.NONE
	var container: Control
	if package.backpack_container.get_global_rect().has_point(screen_position):
		area = BackpackManager.GridType.PACKAGE
		container = package.backpack_container
	elif package.stage_container.get_global_rect().has_point(screen_position):
		area = BackpackManager.GridType.STAGE
		container = package.stage_container
	elif forge.forge_table_grid.get_global_rect().has_point(screen_position):
		area = BackpackManager.GridType.FORGE_TABLE
		container = forge.forge_table_grid
	if container == null:
		card.return_to_origin()
		_refresh_transaction_views()
		return
	var pos := BackpackManager.screen_to_grid(screen_position, container.global_position)
	var result := InventoryOperationResult.rejected(&"invalid_target")
	match source.state:
		BackpackManager.GridType.SHOP:
			result = BackpackManager.try_purchase_equipment(card.offer_id, area, pos, rotation)
		BackpackManager.GridType.FORGE_REWARD:
			result = BackpackManager.try_claim_forge_reward(source.instance_id, area, pos, rotation)
		BackpackManager.GridType.PACKAGE, BackpackManager.GridType.STAGE:
			if area == BackpackManager.GridType.FORGE_TABLE:
				result = BackpackManager.try_select_forge_material(source.instance_id, pos, rotation)
			else:
				result = BackpackManager.try_move_equipment(source.instance_id, area, pos, rotation)
		BackpackManager.GridType.FORGE_TABLE:
			if area == BackpackManager.GridType.FORGE_TABLE:
				result = BackpackManager.try_move_forge_material(source.instance_id, pos, rotation)
			else:
				result = BackpackManager.cancel_forge_material(source.instance_id)
	if not result.success or source.state in [BackpackManager.GridType.SHOP, BackpackManager.GridType.FORGE_REWARD]:
		card.return_to_origin()
	# 成功的变化已经由结果信号刷新；失败或原地放下时主动恢复显示。
	if not result.success or not (result.inventory_changed or result.shop_changed or result.forge_changed):
		_refresh_transaction_views()


func _refresh_transaction_views() -> void:
	# 成功后按正式快照刷新；失败的旧商品请求也需要同步当前货架。
	package._update_view()
	forge._update_view()
	if is_instance_valid(shop):
		shop.update_view()
	_update_all_grid()


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
	if not _switching_panels:
		GameState.leave_current_node()


## 关闭隐藏锻造界面
func _on_forge_exit_button_pressed():
	if not _switching_panels:
		GameState.leave_current_node()


#endregion
