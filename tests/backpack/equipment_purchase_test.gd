extends Node

const FIXTURE := preload("res://tests/backpack/inventory_test_fixture.gd")
const PACKAGE_SCENE := preload("res://scene/shop/package.tscn")
const FORGE_SCENE := preload("res://scene/forge/forge.tscn")
const SHOP_SCENE := preload("res://scene/shop/shop.tscn")
var _panel: PanelManager
var _package: Package
var _forge: Forge
var _shop: Shop
var _balances: Array[int] = []
var _changes: int = 0
var _consistent: bool = true


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	FIXTURE.reset(1, 1)
	_package = PACKAGE_SCENE.instantiate()
	_forge = FORGE_SCENE.instantiate()
	_shop = SHOP_SCENE.instantiate()
	add_child(_package)
	add_child(_forge)
	add_child(_shop)
	_panel = PanelManager.new()
	_panel.package = _package
	_panel.forge = _forge
	_panel.shop = _shop
	BackpackManager.gold_changed.connect(func(value: int): _balances.append(value))
	BackpackManager.equip_changed.connect(func(): _changes += 1)
	for balance in [5, 4]:
		_reset(balance)
		var card := _drag_card()
		_panel._on_equipment_dropped(_cell(Vector2i.ZERO), card)
		var success: bool = balance == 5
		if not _check(BackpackManager.gold == (0 if success else 4), "purchase must charge only on success"):
			return
		if not _check(_changes == (1 if success else 0) and _balances.size() == (1 if success else 0), "purchase publishes one completed change or none"):
			return
		if not _check(_package.backpack_cards.size() == (1 if success else 0) and card.visible != success, "views must reflect inventory and sold state"):
			return
		if success:
			var sold_id := card.offer_id
			var duplicate := BackpackManager.try_purchase_equipment(sold_id, BackpackManager.GridType.STAGE, Vector2i.ZERO)
			if not _check(not duplicate.success and BackpackManager.stage_equip.is_empty(), "sold offers must not be purchased twice"):
				return
	_reset(5)
	_panel._on_equipment_dropped(_cell(Vector2i(1, 0)), _drag_card())
	if not _check(BackpackManager.gold == 5 and _changes == 0 and _balances.is_empty(), "invalid placement must leave all data unchanged"):
		return
	_reset(10)
	var card := _drag_card()
	var old_offer := card.offer_id
	var reentrant := {"accepted": true}
	var listener := func():
		_consistent = BackpackManager.gold == 5 and BackpackManager.backpack_equip.size() == 1 and BackpackManager.get_shop_offers()[0].sold
		reentrant.accepted = BackpackManager.spend_gold(5)
	BackpackManager.equip_changed.connect(listener, CONNECT_ONE_SHOT)
	_panel._on_equipment_dropped(_cell(Vector2i.ZERO), card)
	if not _check(_consistent and not reentrant.accepted and BackpackManager.gold == 5, "listeners must see committed state and cannot interleave writes"):
		return
	# 重建商店界面仍显示同一批商品的售出状态。
	_shop.free()
	_shop = SHOP_SCENE.instantiate()
	add_child(_shop)
	_panel.shop = _shop
	if not _check(not _shop.get_cards()[0].visible and BackpackManager.get_shop_offers()[0].offer_id == old_offer, "sold state must survive view recreation"):
		return
	_reset(5)
	card = _drag_card()
	old_offer = card.offer_id
	BackpackManager.refresh_shop([12, 12, 12, 12])
	_panel._on_equipment_dropped(_cell(Vector2i.ZERO), card)
	if not _check(BackpackManager.gold == 5 and _changes == 0 and card.offer_id != old_offer and card.visible, "stale drag requests must not buy refreshed offers"):
		return
	# 查询数据是副本，外部写入不能破坏正式状态。
	var grid := BackpackManager.backpack_grid
	grid[0][0] = 1
	var offers := BackpackManager.get_shop_offers()
	offers[0].price = 0
	if not _check(BackpackManager.backpack_grid[0][0] == 0 and BackpackManager.get_shop_offers()[0].price == 5, "query snapshots must not expose mutable state"):
		return
	_panel.free()
	_package.queue_free()
	_forge.queue_free()
	_shop.queue_free()
	await get_tree().process_frame
	print("PASS: atomic purchases, signal consistency, reentrant rejection, stale offers and view recreation")
	get_tree().quit(0)


func _reset(balance: int) -> void:
	FIXTURE.reset(1, 1)
	BackpackManager.refresh_shop([12, 12, 12, 12])
	BackpackManager.set_gold(balance)
	_balances.clear()
	_changes = 0


func _drag_card() -> EquipmentCard:
	var card := _shop.get_cards()[0]
	card._on_drag_start(card.global_position + card.pivot_offset)
	card._on_drag_move(card.global_position)
	return card


func _cell(pos: Vector2i) -> Vector2:
	return _package.backpack_container.global_position + Vector2(pos) * BackpackManager.CELL_SIZE + Vector2.ONE * 24.0


func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("PURCHASE TEST FAILED: " + message)
		get_tree().quit(1)
	return ok
