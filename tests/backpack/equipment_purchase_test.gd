extends Node

const EQUIPMENT_CARD_SCENE: PackedScene = preload("res://scene/shop/equipment_card.tscn")
const PACKAGE_SCENE: PackedScene = preload("res://scene/shop/package.tscn")
const FORGE_SCENE: PackedScene = preload("res://scene/forge/forge.tscn")
const SHOP_EQUIPMENT_ID: int = 12
const SHOP_EQUIPMENT_PRICE: int = 5

var _observed_gold: Array[int] = []
var _observed_equipment_changes: int = 0
var _panel_manager: PanelManager
var _package: Package
var _forge: Forge
var _card_parent: Control


func _ready() -> void:
	BackpackManager.gold_changed.connect(_on_gold_changed)
	BackpackManager.equip_changed.connect(_on_equipment_changed)
	call_deferred("_run")


func _run() -> void:
	_build_purchase_harness()
	if not _test_exact_funds_purchase_succeeds():
		return
	if not _test_insufficient_funds_preserve_transaction_state():
		return
	if not _test_failed_placement_does_not_spend():
		return
	if not _test_post_placement_spend_failure_rolls_back_equipment():
		return
	_panel_manager.free()
	_package.queue_free()
	_forge.queue_free()
	_card_parent.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)


func _build_purchase_harness() -> void:
	_reset_transaction_state(0)
	_package = PACKAGE_SCENE.instantiate() as Package
	add_child(_package)
	_forge = FORGE_SCENE.instantiate() as Forge
	add_child(_forge)
	_card_parent = Control.new()
	add_child(_card_parent)
	_panel_manager = PanelManager.new()
	_panel_manager.package = _package
	_panel_manager.forge = _forge


func _test_exact_funds_purchase_succeeds() -> bool:
	_reset_transaction_state(SHOP_EQUIPMENT_PRICE)
	var card := _create_shop_card()
	_panel_manager._on_equipment_dropped(_backpack_cell_center(Vector2i.ZERO), card)

	if not _assert(BackpackManager.gold == 0, "exact-funds purchase should spend the full balance"):
		return false
	if not _assert(_observed_gold == [0], "exact-funds purchase should emit the resulting zero balance"):
		return false
	if not _assert(BackpackManager.backpack_grid[0][0] == 1, "exact-funds purchase should occupy the target grid cell"):
		return false
	if not _assert(BackpackManager.backpack_equip.size() == 1, "exact-funds purchase should add one equipment"):
		return false
	if not _assert(BackpackManager.backpack_equip.has(Vector2i.ZERO), "exact-funds purchase should store equipment at the drop cell"):
		return false
	var placed_equipment: Equipment = BackpackManager.backpack_equip[Vector2i.ZERO]
	if not _assert(placed_equipment.id == SHOP_EQUIPMENT_ID, "exact-funds purchase should place the offered equipment"):
		return false
	if not _assert(placed_equipment.state == BackpackManager.GridType.PACKAGE, "purchased equipment should belong to the backpack grid"):
		return false
	if not _assert(not card.visible, "successful purchase should hide the shop card"):
		return false
	if not _assert(_card_is_at_shop_origin(card), "successful purchase should restore the source card data"):
		return false
	return _assert(_observed_equipment_changes == 1, "successful purchase should emit one equipment change")


func _test_insufficient_funds_preserve_transaction_state() -> bool:
	_reset_transaction_state(SHOP_EQUIPMENT_PRICE - 1)
	var card := _create_shop_card()
	_panel_manager._on_equipment_dropped(_backpack_cell_center(Vector2i.ZERO), card)

	if not _assert(BackpackManager.gold == 4, "insufficient purchase should preserve the balance"):
		return false
	if not _assert(_observed_gold.is_empty(), "insufficient purchase should not emit a balance"):
		return false
	if not _assert(BackpackManager.backpack_grid[0][0] == 0, "insufficient purchase should leave the grid empty"):
		return false
	if not _assert(BackpackManager.backpack_equip.is_empty(), "insufficient purchase should not add equipment"):
		return false
	if not _assert(card.visible, "insufficient purchase should keep the shop card visible"):
		return false
	if not _assert(_card_is_at_shop_origin(card), "insufficient purchase should restore the shop card origin"):
		return false
	return _assert(_observed_equipment_changes == 0, "insufficient purchase should not transiently place equipment")


func _test_failed_placement_does_not_spend() -> bool:
	_reset_transaction_state(SHOP_EQUIPMENT_PRICE)
	var card := _create_shop_card()
	_panel_manager._on_equipment_dropped(_backpack_cell_center(Vector2i(1, 0)), card)

	if not _assert(BackpackManager.gold == 5, "failed placement should preserve the balance"):
		return false
	if not _assert(_observed_gold.is_empty(), "failed placement should not emit a balance"):
		return false
	if not _assert(BackpackManager.backpack_grid[0][0] == 0, "failed placement should leave the grid empty"):
		return false
	if not _assert(BackpackManager.backpack_equip.is_empty(), "failed placement should not add equipment"):
		return false
	if not _assert(card.visible, "failed placement should keep the shop card visible"):
		return false
	if not _assert(_card_is_at_shop_origin(card), "failed placement should restore the shop card origin"):
		return false
	return _assert(_observed_equipment_changes == 0, "failed placement should not emit an equipment change")


func _test_post_placement_spend_failure_rolls_back_equipment() -> bool:
	_reset_transaction_state(SHOP_EQUIPMENT_PRICE)
	var card := _create_shop_card()
	var consume_balance_on_placement := func() -> void:
		BackpackManager.spend_gold(SHOP_EQUIPMENT_PRICE)
	BackpackManager.equip_changed.connect(consume_balance_on_placement, CONNECT_ONE_SHOT)

	_panel_manager._on_equipment_dropped(_backpack_cell_center(Vector2i.ZERO), card)

	if not _assert(BackpackManager.gold == 0, "forced spend failure should preserve the listener-updated balance"):
		return false
	if not _assert(_observed_gold == [0], "forced spend failure should emit only the listener-updated balance"):
		return false
	if not _assert(BackpackManager.backpack_grid[0][0] == 0, "forced spend failure should release the placed grid cell"):
		return false
	if not _assert(BackpackManager.backpack_equip.is_empty(), "forced spend failure should remove the placed equipment"):
		return false
	if not _assert(card.visible, "forced spend failure should keep the shop card visible"):
		return false
	if not _assert(_card_is_at_shop_origin(card), "forced spend failure should restore the shop card origin"):
		return false
	return _assert(_observed_equipment_changes == 2, "forced spend failure should emit placement and rollback changes")


func _reset_transaction_state(balance: int) -> void:
	BackpackManager.backpack_grid = [[0]]
	BackpackManager.stage_grid = [[0]]
	BackpackManager.forge_grid = [[0]]
	BackpackManager.backpack_equip.clear()
	BackpackManager.stage_equip.clear()
	BackpackManager.forge_equip.clear()
	BackpackManager._notify_equipment_changed()
	BackpackManager.set_gold(balance)
	_observed_gold.clear()
	_observed_equipment_changes = 0


func _create_shop_card() -> EquipmentCard:
	var card := EQUIPMENT_CARD_SCENE.instantiate() as EquipmentCard
	_card_parent.add_child(card)
	card.setup(SHOP_EQUIPMENT_ID, BackpackManager.GridType.SHOP)
	card.position = Vector2(640.0, 96.0)
	card._on_drag_start(card.global_position + card.pivot_offset)
	return card


func _backpack_cell_center(grid_pos: Vector2i) -> Vector2:
	return _package.backpack_container.global_position + Vector2(
		grid_pos.x * BackpackManager.CELL_SIZE + BackpackManager.CELL_SIZE / 2.0,
		grid_pos.y * BackpackManager.CELL_SIZE + BackpackManager.CELL_SIZE / 2.0
	)


func _card_is_at_shop_origin(card: EquipmentCard) -> bool:
	return (
		card.equipment.state == BackpackManager.GridType.SHOP
		and card.equipment.grid_pos == Vector2i.ZERO
	)


func _on_gold_changed(current_gold: int) -> void:
	_observed_gold.append(current_gold)


func _on_equipment_changed() -> void:
	_observed_equipment_changes += 1


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("EQUIPMENT PURCHASE TEST FAILED: %s" % message)
	get_tree().quit(1)
	return false
