class_name InventoryService
extends RefCounted
## 同步提交完整操作，不引用场景、卡牌或发布中间信号。

const PACKAGE: int = BackpackManager.GridType.PACKAGE
const STAGE: int = BackpackManager.GridType.STAGE
const FORGE_REWARD: int = BackpackManager.GridType.FORGE_REWARD

var _inventory: InventoryState
var _shop: ShopState
var _forge: ForgeState
var _next_instance_id: int = 1
var _next_offer_id: int = 1


func _init(inventory: InventoryState, shop: ShopState, forge: ForgeState) -> void:
	_inventory = inventory
	_shop = shop
	_forge = forge


func initialize(character_id: int) -> InventoryOperationResult:
	var character: CharacterData = GameConfig.characters.get(character_id)
	if character == null or character.backpack_shape.is_empty():
		return _fail(&"invalid_character")
	var layout := character.backpack_shape
	if layout.size() > 6 or layout[0].size() > 8:
		return _fail(&"invalid_layout")
	var backpack := GridRules.rectangle(8, 6, -1)
	var offset := Vector2i((8 - layout[0].size()) / 2, (6 - layout.size()) / 2)
	for y in layout.size():
		if layout[y].size() != layout[0].size():
			return _fail(&"invalid_layout")
		for x in layout[y].size():
			if layout[y][x] == 1:
				backpack[y + offset.y][x + offset.x] = 0
	var initial: Array[Equipment] = []
	for config_id in character.init_equipments:
		if not GameConfig.equipment.has(config_id):
			return _fail(&"invalid_equipment")
		var item := Equipment.new(config_id)
		var pos := GridRules.find_position(item.shape, backpack)
		if pos.x < 0:
			return _fail(&"no_space")
		item.state = PACKAGE
		item.grid_pos = pos
		GridRules.mark(item.shape, pos, backpack, 1)
		initial.append(item)
	# 所有校验完成后替换本局数据；编号保持递增，旧请求不能命中新局。
	_inventory.items.clear()
	_inventory.grids = {PACKAGE: backpack, STAGE: GridRules.rectangle(8, 4)}
	_inventory.grid_cost = 10
	_inventory.purchase_mode = false
	_shop.node_key = ""
	_shop.pool.clear()
	_shop.offers.clear()
	_forge.selections.clear()
	_forge.pending_reward = null
	for item in initial:
		item.instance_id = _allocate_id()
		_inventory.items[item.instance_id] = item
	var result := _ok()
	result.inventory_changed = true
	result.shop_changed = true
	result.forge_changed = true
	result.grid_changed = true
	return result


func set_gold(amount: int) -> InventoryOperationResult:
	var result := _ok()
	var next := maxi(amount, 0)
	result.gold_changed = next != _inventory.gold
	_inventory.gold = next
	return result


func add_gold(amount: int) -> InventoryOperationResult:
	if amount <= 0:
		return _fail(&"invalid_amount")
	return set_gold(_inventory.gold + amount)


func spend_gold(amount: int) -> InventoryOperationResult:
	if amount <= 0 or amount > _inventory.gold:
		return _fail(&"insufficient_gold")
	return set_gold(_inventory.gold - amount)


func set_purchase_mode(enabled: bool) -> InventoryOperationResult:
	var result := _ok()
	result.grid_changed = enabled != _inventory.purchase_mode
	_inventory.purchase_mode = enabled
	return result


func purchase_grid(pos: Vector2i) -> InventoryOperationResult:
	var grid := _grid(PACKAGE)
	if not _inventory.purchase_mode or pos not in GridRules.purchasable_cells(grid):
		return _fail(&"invalid_grid")
	if _inventory.gold < _inventory.grid_cost:
		return _fail(&"insufficient_gold")
	_inventory.gold -= _inventory.grid_cost
	grid[pos.y][pos.x] = 0
	_inventory.grid_cost *= 2
	var result := _ok()
	result.gold_changed = true
	result.grid_changed = true
	result.affected_grids = [PACKAGE]
	return result


func open_shop(node_key: String, config_id: int) -> InventoryOperationResult:
	if node_key == _shop.node_key and not _shop.offers.is_empty():
		return _ok()
	var config: ShopConfigData = GameConfig.shops.get(config_id)
	if config == null or config.equipment_ids.is_empty():
		return _fail(&"invalid_shop")
	var pool: Array[int] = []
	pool.assign(config.equipment_ids)
	var ids := _roll(pool)
	if not _valid_offers(ids):
		return _fail(&"invalid_equipment")
	_shop.node_key = node_key
	_shop.pool = pool
	return _replace_offers(ids)


func refresh_shop(ids: Array[int] = []) -> InventoryOperationResult:
	var next := ids if not ids.is_empty() else _roll(_shop.pool)
	if not _valid_offers(next):
		return _fail(&"invalid_offers")
	return _replace_offers(next)


func purchase(offer_id: int, area: int, pos: Vector2i, rotation: int) -> InventoryOperationResult:
	var offer: Dictionary = {}
	for candidate in _shop.offers:
		if candidate.offer_id == offer_id:
			offer = candidate
			break
	if offer.is_empty() or offer.sold:
		return _fail(&"offer_unavailable")
	if _inventory.gold < int(offer.price):
		return _fail(&"insufficient_gold")
	var item := _candidate(offer.config_id, area, pos, rotation)
	if item == null or not GridRules.can_place(item.shape, pos, _grid(area)):
		return _fail(&"no_space")
	_inventory.gold -= int(offer.price)
	offer.sold = true
	_insert(item)
	var result := _inventory_result(area)
	result.gold_changed = int(offer.price) != 0
	result.shop_changed = true
	result.added_ids.append(item.instance_id)
	return result


## 初始奖励、调试及其他业务系统发放装备也经过完整放置校验。
func grant(config_id: int, area: int, pos: Vector2i, rotation: int = 0) -> InventoryOperationResult:
	var item := _candidate(config_id, area, pos, rotation)
	if item == null or not GridRules.can_place(item.shape, pos, _grid(area)):
		return _fail(&"no_space")
	_insert(item)
	var result := _inventory_result(area)
	result.added_ids.append(item.instance_id)
	return result


func move(instance_id: int, area: int, pos: Vector2i, rotation: int) -> InventoryOperationResult:
	var item: Equipment = _inventory.items.get(instance_id)
	if item == null:
		return _fail(&"item_missing")
	if _forge.selections.has(instance_id):
		return _fail(&"material_reserved")
	var proposed := _candidate(item.id, area, pos, rotation)
	if proposed == null:
		return _fail(&"invalid_target")
	var grid: Array[Array] = _grid(area).duplicate(true)
	if area == int(item.state):
		GridRules.mark(item.shape, item.grid_pos, grid, 0)
	if not GridRules.can_place(proposed.shape, pos, grid):
		return _fail(&"no_space")
	if item.state == area and item.grid_pos == pos and item.rotate_times == rotation:
		return _ok()
	var previous_area := int(item.state)
	GridRules.mark(item.shape, item.grid_pos, _grid(previous_area), 0)
	item.state = area
	item.grid_pos = pos
	item.rotate_times = rotation
	item.shape = proposed.shape
	GridRules.mark(item.shape, pos, _grid(area), 1)
	var result := _inventory_result(area)
	if previous_area != area:
		result.affected_grids.append(previous_area)
	result.moved_ids.append(instance_id)
	return result


func remove(instance_id: int) -> InventoryOperationResult:
	var item: Equipment = _inventory.items.get(instance_id)
	if item == null or _forge.selections.has(instance_id):
		return _fail(&"item_missing_or_reserved")
	var result := _inventory_result(item.state)
	result.removed_ids.append(instance_id)
	_erase(item)
	return result


func select_material(instance_id: int, pos: Vector2i, rotation: int, reposition: bool = false) -> InventoryOperationResult:
	if _forge.pending_reward != null:
		return _fail(&"reward_pending")
	var item: Equipment = _inventory.items.get(instance_id)
	if item == null:
		return _fail(&"item_missing")
	if _forge.selections.has(instance_id) != reposition:
		return _fail(&"invalid_selection")
	if rotation < 0 or rotation > 3:
		return _fail(&"invalid_rotation")
	var shape := GridRules.rotated(GameConfig.equipment[item.id].shape, rotation)
	if not GridRules.can_place(shape, pos, forge_grid(instance_id if reposition else 0)):
		return _fail(&"no_space")
	_forge.selections[instance_id] = {"position": pos, "rotation": rotation}
	var result := _ok()
	result.forge_changed = true
	return result


func cancel_material(instance_id: int) -> InventoryOperationResult:
	if not _forge.selections.has(instance_id):
		return _fail(&"invalid_selection")
	_forge.selections.erase(instance_id)
	var result := _ok()
	result.forge_changed = true
	return result


func clear_selection() -> InventoryOperationResult:
	var result := _ok()
	result.forge_changed = not _forge.selections.is_empty()
	_forge.selections.clear()
	return result


func preview_recipe() -> EquipmentForgeData:
	var ids: Array[int] = []
	for instance_id in _forge.selections:
		var item: Equipment = _inventory.items.get(instance_id)
		if item == null:
			return null
		ids.append(item.id)
	return ForgeRules.find_recipe(ids, GameConfig.forges)


func forge() -> InventoryOperationResult:
	if _forge.pending_reward != null:
		return _fail(&"reward_pending")
	var recipe := preview_recipe()
	if recipe == null or not GameConfig.equipment.has(recipe.equipment_id) or recipe.coin < 0:
		return _fail(&"invalid_recipe")
	if _inventory.gold < recipe.coin:
		return _fail(&"insufficient_gold")
	var reward := Equipment.new(recipe.equipment_id)
	reward.instance_id = _allocate_id()
	reward.state = FORGE_REWARD
	var result := _ok()
	result.inventory_changed = true
	result.gold_changed = recipe.coin != 0
	result.forge_changed = true
	for instance_id in _forge.selections:
		var item: Equipment = _inventory.items[instance_id]
		if int(item.state) not in result.affected_grids:
			result.affected_grids.append(int(item.state))
		result.removed_ids.append(instance_id)
		_erase(item)
	_inventory.gold -= recipe.coin
	_forge.selections.clear()
	_forge.pending_reward = reward
	result.added_ids.append(reward.instance_id)
	return result


func claim_reward(instance_id: int, area: int, pos: Vector2i, rotation: int) -> InventoryOperationResult:
	var reward := _forge.pending_reward
	if reward == null or reward.instance_id != instance_id:
		return _fail(&"reward_missing")
	var proposed := _candidate(reward.id, area, pos, rotation)
	if proposed == null or not GridRules.can_place(proposed.shape, pos, _grid(area)):
		return _fail(&"no_space")
	reward.state = area
	reward.grid_pos = pos
	reward.rotate_times = rotation
	reward.shape = proposed.shape
	_inventory.items[reward.instance_id] = reward
	GridRules.mark(reward.shape, pos, _grid(area), 1)
	_forge.pending_reward = null
	var result := _inventory_result(area)
	result.forge_changed = true
	result.moved_ids.append(reward.instance_id)
	return result


func forge_grid(exclude_id: int = 0) -> Array[Array]:
	var grid := GridRules.rectangle(8, 4)
	for instance_id in _forge.selections:
		if instance_id == exclude_id:
			continue
		var item: Equipment = _inventory.items.get(instance_id)
		if item != null:
			var selection: Dictionary = _forge.selections[instance_id]
			var shape := GridRules.rotated(GameConfig.equipment[item.id].shape, selection.rotation)
			GridRules.mark(shape, selection.position, grid, 1)
	return grid


func _candidate(config_id: int, area: int, pos: Vector2i, rotation: int) -> Equipment:
	if area not in [PACKAGE, STAGE] or rotation < 0 or rotation > 3 or not GameConfig.equipment.has(config_id):
		return null
	var item := Equipment.new(config_id)
	item.shape = GridRules.rotated(item.shape, rotation)
	item.rotate_times = rotation
	item.state = area
	item.grid_pos = pos
	return item


func _grid(area: int) -> Array[Array]:
	var result: Array[Array] = []
	result.assign(_inventory.grids.get(area, []))
	return result


func _insert(item: Equipment) -> void:
	item.instance_id = _allocate_id()
	_inventory.items[item.instance_id] = item
	GridRules.mark(item.shape, item.grid_pos, _grid(item.state), 1)


func _erase(item: Equipment) -> void:
	GridRules.mark(item.shape, item.grid_pos, _grid(item.state), 0)
	_inventory.items.erase(item.instance_id)


func _allocate_id() -> int:
	var id := _next_instance_id
	_next_instance_id += 1
	return id


func _roll(pool: Array[int]) -> Array[int]:
	if pool.is_empty():
		return []
	var ids: Array[int] = pool.duplicate()
	ids.shuffle()
	while ids.size() < ShopState.CARD_COUNT:
		ids.append(pool.pick_random())
	return ids.slice(0, ShopState.CARD_COUNT)


func _valid_offers(ids: Array[int]) -> bool:
	if ids.size() != ShopState.CARD_COUNT:
		return false
	for id in ids:
		if not GameConfig.equipment.has(id) or GameConfig.equipment[id].price < 0:
			return false
	return true


func _replace_offers(ids: Array[int]) -> InventoryOperationResult:
	_shop.offers.clear()
	for id in ids:
		_shop.offers.append({"offer_id": _next_offer_id, "config_id": id,
			"price": GameConfig.equipment[id].price, "sold": false})
		_next_offer_id += 1
	var result := _ok()
	result.shop_changed = true
	return result


func _inventory_result(area: int) -> InventoryOperationResult:
	var result := _ok()
	result.inventory_changed = true
	result.affected_grids.append(area)
	return result


func _ok() -> InventoryOperationResult:
	return InventoryOperationResult.accepted()


func _fail(reason: StringName) -> InventoryOperationResult:
	return InventoryOperationResult.rejected(reason)
