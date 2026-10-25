extends Node
## 跨场景入口：持有业务状态，服务完成提交后统一刷新属性并通知。

enum GridType {NONE = -1, PACKAGE = 0, STAGE, SHOP, FORGE_TABLE, FORGE_REWARD}

const CELL_SIZE: int = 48
const BACKPACK_COLS: int = 8
const BACKPACK_ROWS: int = 6
const STAGE_COLS: int = 8
const STAGE_ROWS: int = 4
const FORGE_COLS: int = 8
const FORGE_ROWS: int = 4
const INITIAL_GRID_COST: int = 10

signal equip_changed()
signal grid_purchase_state_changed()
signal gold_changed(current_gold: int)
signal shop_changed()
signal forge_changed()
signal operation_completed(result: InventoryOperationResult)

var _inventory := InventoryState.new()
var _shop := ShopState.new()
var _forge := ForgeState.new()
var _service := InventoryService.new(_inventory, _shop, _forge)
var _publishing: bool = false
var equipment_attrs := AttrContainer.new()

var gold: int:
	get: return _inventory.gold
var grid_cost: int:
	get: return _inventory.grid_cost
var is_grid_purchase_mode: bool:
	get: return _inventory.purchase_mode
var backpack_grid: Array[Array]:
	get: return get_grid(GridType.PACKAGE)
var stage_grid: Array[Array]:
	get: return get_grid(GridType.STAGE)
var forge_grid: Array[Array]:
	get: return _service.forge_grid()
var backpack_equip: Dictionary[Vector2i, Equipment]:
	get: return get_equipment_in_grid(GridType.PACKAGE)
var stage_equip: Dictionary[Vector2i, Equipment]:
	get: return get_equipment_in_grid(GridType.STAGE)
var forge_equip: Dictionary[Vector2i, Equipment]:
	get: return get_forge_materials()
var equipments: Dictionary:
	get: return backpack_equip


func init_backpack(character_id: int) -> void:
	_execute(_service.initialize.bind(character_id))


func set_gold(amount: int) -> void:
	_execute(_service.set_gold.bind(amount))


func add_gold(amount: int) -> bool:
	return _execute(_service.add_gold.bind(amount)).success


func spend_gold(amount: int) -> bool:
	return _execute(_service.spend_gold.bind(amount)).success


func set_grid_purchase_mode(enabled: bool) -> void:
	_execute(_service.set_purchase_mode.bind(enabled))


func get_purchasable_grid_cells() -> Array[Vector2i]:
	return GridRules.purchasable_cells(backpack_grid)


func purchase_grid(pos: Vector2i) -> bool:
	return _execute(_service.purchase_grid.bind(pos)).success


func open_shop(node_key: String, config_id: int) -> InventoryOperationResult:
	return _execute(_service.open_shop.bind(node_key, config_id))


func refresh_shop(ids: Array[int] = []) -> InventoryOperationResult:
	return _execute(_service.refresh_shop.bind(ids))


func try_purchase_equipment(offer_id: int, area: int, pos: Vector2i, rotation: int = 0) -> InventoryOperationResult:
	return _execute(_service.purchase.bind(offer_id, area, pos, rotation))


func try_move_equipment(instance_id: int, area: int, pos: Vector2i, rotation: int = 0) -> InventoryOperationResult:
	return _execute(_service.move.bind(instance_id, area, pos, rotation))


func try_select_forge_material(instance_id: int, pos: Vector2i, rotation: int = 0) -> InventoryOperationResult:
	return _execute(_service.select_material.bind(instance_id, pos, rotation))


func try_move_forge_material(instance_id: int, pos: Vector2i, rotation: int) -> InventoryOperationResult:
	return _execute(_service.select_material.bind(instance_id, pos, rotation, true))


func cancel_forge_material(instance_id: int) -> InventoryOperationResult:
	return _execute(_service.cancel_material.bind(instance_id))


func clear_forge_selection() -> InventoryOperationResult:
	return _execute(_service.clear_selection)


func try_forge() -> InventoryOperationResult:
	return _execute(_service.forge)


func try_claim_forge_reward(instance_id: int, area: int, pos: Vector2i, rotation: int = 0) -> InventoryOperationResult:
	return _execute(_service.claim_reward.bind(instance_id, area, pos, rotation))


func grant_equipment(config_id: int, area: int, pos: Vector2i, rotation: int = 0) -> InventoryOperationResult:
	return _execute(_service.grant.bind(config_id, area, pos, rotation))


## 兼容已有奖励调用；传入对象是快照，正式数据由服务创建。
func add_to_equip_grid(equipment: Equipment, pos: Vector2i) -> bool:
	if equipment == null or equipment.instance_id != 0:
		return false
	var result := grant_equipment(equipment.id, equipment.state, pos, equipment.rotate_times)
	if result.success:
		equipment.instance_id = result.added_ids[0]
		equipment.grid_pos = pos
	return result.success


func remove_equipment(equipment: Equipment) -> bool:
	if equipment == null:
		return false
	return _execute(_service.remove.bind(equipment.instance_id)).success


func get_equipment(instance_id: int) -> Equipment:
	var item: Equipment = _inventory.items.get(instance_id)
	return item.copy() if item != null else null


func get_grid(area: int) -> Array[Array]:
	var result: Array[Array] = []
	result.assign(_inventory.grids.get(area, []))
	return result.duplicate(true)


func get_equipment_in_grid(area: int) -> Dictionary[Vector2i, Equipment]:
	var result: Dictionary[Vector2i, Equipment] = {}
	for item: Equipment in _inventory.items.values():
		if int(item.state) == area:
			result[item.grid_pos] = item.copy()
	return result


func get_shop_offers() -> Array[Dictionary]:
	return _shop.offers.duplicate(true)


func is_material_selected(instance_id: int) -> bool:
	return _forge.selections.has(instance_id)


func get_forge_materials() -> Dictionary[Vector2i, Equipment]:
	var result: Dictionary[Vector2i, Equipment] = {}
	for instance_id in _forge.selections:
		var item := get_equipment(instance_id)
		if item == null:
			continue
		var selection: Dictionary = _forge.selections[instance_id]
		item.state = GridType.FORGE_TABLE
		item.grid_pos = selection.position
		item.rotate_times = selection.rotation
		item.shape = GridRules.rotated(GameConfig.equipment[item.id].shape, item.rotate_times)
		result[item.grid_pos] = item
	return result


func get_pending_forge_reward() -> Equipment:
	return _forge.pending_reward.copy() if _forge.pending_reward != null else null


func get_forge_preview_id() -> int:
	var recipe := _service.preview_recipe()
	return recipe.equipment_id if recipe != null else 0


func get_forge_cost() -> int:
	var recipe := _service.preview_recipe()
	return recipe.coin if recipe != null else 0


func _execute(action: Callable) -> InventoryOperationResult:
	# 同步监听者可以查询最终状态，但不能在一组通知中插入另一笔写操作。
	if _publishing:
		return InventoryOperationResult.rejected(&"operation_busy")
	_publishing = true
	var result: InventoryOperationResult = action.call()
	if result.success:
		if result.inventory_changed:
			recalculate_equipment_attrs()
		if result.gold_changed:
			gold_changed.emit(gold)
		if result.inventory_changed:
			equip_changed.emit()
		if result.shop_changed:
			shop_changed.emit()
		if result.forge_changed:
			forge_changed.emit()
		if result.grid_changed:
			grid_purchase_state_changed.emit()
		operation_completed.emit(result)
	_publishing = false
	return result


func recalculate_equipment_attrs() -> void:
	equipment_attrs.reset()
	for equipment: Equipment in _inventory.items.values():
		if equipment.state != GridType.PACKAGE:
			continue
		var data: EquipmentData = GameConfig.equipment.get(equipment.id)
		if data == null or data.type != EquipmentEffectType.Type.PASSIVE_ATTRIBUTE:
			continue
		for key in data.attr:
			var type := AttrType.get_type(String(key))
			if int(type) == -1:
				continue
			var total := equipment_attrs.get_value(type) if equipment_attrs.has(type) else 0.0
			equipment_attrs.set_value(type, total + float(data.attr[key]))


func can_place(shape: Array[Array], pos: Vector2i, grid: Array[Array]) -> bool:
	return GridRules.can_place(shape, pos, grid)


func find_position(shape: Array[Array], grid: Array[Array]) -> Vector2i:
	return GridRules.find_position(shape, grid)


## 像素转换仅供界面使用，业务请求只接受网格坐标。
func screen_to_grid(screen_pos: Vector2, container_pos: Vector2) -> Vector2i:
	var local := (screen_pos - container_pos) / CELL_SIZE
	return Vector2i(floori(local.x), floori(local.y))


func grid_to_pixel(pos: Vector2i, grid_container: Control, card_container: Control) -> Vector2:
	return grid_container.global_position + Vector2(pos) * CELL_SIZE - card_container.global_position
