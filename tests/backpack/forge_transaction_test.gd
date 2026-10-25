extends Node

const FIXTURE := preload("res://tests/backpack/inventory_test_fixture.gd")
const FORGE_SCENE := preload("res://scene/forge/forge.tscn")
var _changes: int = 0
var _gold_changes: int = 0


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	FIXTURE.reset()
	var sword: Equipment = FIXTURE.add(1)
	var bow: Equipment = FIXTURE.add(3)
	if not _check(sword.instance_id != bow.instance_id, "items must have unique identifiers"):
		return
	BackpackManager.try_select_forge_material(sword.instance_id, Vector2i.ZERO)
	var duplicate := BackpackManager.try_select_forge_material(sword.instance_id, Vector2i(2, 0))
	if not _check(not duplicate.success and BackpackManager.get_forge_materials().size() == 1, "one item cannot be selected twice"):
		return
	if not _check(not BackpackManager.try_forge().success and BackpackManager.get_equipment(sword.instance_id) != null, "invalid recipes must not consume materials"):
		return
	BackpackManager.try_select_forge_material(bow.instance_id, Vector2i(1, 0))
	if not _check(BackpackManager.get_forge_preview_id() == 4, "real config recipe must match selected material IDs"):
		return
	# 配方数量必须保留；两个相同配置仍要求两个独立实例。
	var repeated_recipe := EquipmentForgeData.from_dict({"EquipmentID": 4, "MaterialIDs": "1,1", "Coin": 0})
	if not _check(ForgeRules.find_recipe([1], {4: repeated_recipe}) == null and ForgeRules.find_recipe([1, 1], {4: repeated_recipe}) != null, "recipe matching must retain multiplicity"):
		return
	BackpackManager.set_gold(9)
	var before := BackpackManager.backpack_grid
	if not _check(not BackpackManager.try_forge().success and BackpackManager.gold == 9 and before == BackpackManager.backpack_grid and BackpackManager.get_forge_materials().size() == 2, "insufficient forge funds must preserve materials and selection"):
		return
	BackpackManager.set_gold(10)
	BackpackManager.equip_changed.connect(func(): _changes += 1)
	BackpackManager.gold_changed.connect(func(_gold: int): _gold_changes += 1)
	var observed := {"complete": false}
	var on_commit := func():
		observed.complete = BackpackManager.gold == 0 and BackpackManager.backpack_equip.is_empty() and BackpackManager.get_pending_forge_reward() != null and BackpackManager.get_forge_materials().is_empty()
	BackpackManager.equip_changed.connect(on_commit, CONNECT_ONE_SHOT)
	var result := BackpackManager.try_forge()
	if not _check(result.success and observed.complete and _changes == 1 and _gold_changes == 1, "forge must publish once after all materials, gold and reward are committed"):
		return
	var reward := BackpackManager.get_pending_forge_reward()
	if not _check(reward.id == 4 and reward.instance_id != sword.instance_id, "forge must create a new actual instance"):
		return
	if not _check(not BackpackManager.try_forge().success and not BackpackManager.try_select_forge_material(bow.instance_id, Vector2i.ZERO).success, "pending reward cannot be overwritten"):
		return
	# 不加载界面也已完成锻造；随后创建/销毁界面不能丢失成品。
	var view := FORGE_SCENE.instantiate() as Forge
	add_child(view)
	if not _check(view.result_equipment_card.visible and view.result_equipment_card.mouse_filter != Control.MOUSE_FILTER_IGNORE, "pending reward must render as claimable"):
		return
	view.free()
	BackpackManager.clear_forge_selection()
	view = FORGE_SCENE.instantiate()
	add_child(view)
	if not _check(view.result_equipment_card.equipment.instance_id == reward.instance_id, "reward must survive closing and reopening"):
		return
	result = BackpackManager.try_claim_forge_reward(reward.instance_id, BackpackManager.GridType.PACKAGE, Vector2i(7, 5))
	if not _check(not result.success and BackpackManager.get_pending_forge_reward().instance_id == reward.instance_id, "failed claim must preserve the reward"):
		return
	result = BackpackManager.try_claim_forge_reward(reward.instance_id, BackpackManager.GridType.STAGE, Vector2i.ZERO)
	if not _check(result.success and BackpackManager.get_pending_forge_reward() == null and BackpackManager.get_equipment(reward.instance_id).id == 4, "successful claim must transfer the same reward exactly once"):
		return
	if not _check(not BackpackManager.try_claim_forge_reward(reward.instance_id, BackpackManager.GridType.STAGE, Vector2i(1, 0)).success, "duplicate claim must fail"):
		return
	view.free()
	# 未领取成品、材料选择、货架在新局均清空。
	FIXTURE.reset()
	sword = FIXTURE.add(1)
	bow = FIXTURE.add(3)
	BackpackManager.try_select_forge_material(sword.instance_id, Vector2i.ZERO)
	BackpackManager.try_select_forge_material(bow.instance_id, Vector2i(1, 0))
	BackpackManager.try_forge()
	BackpackManager.refresh_shop([12, 12, 12, 12])
	BackpackManager.init_backpack(1)
	if not _check(BackpackManager.get_pending_forge_reward() == null and BackpackManager.get_forge_materials().is_empty() and BackpackManager.get_shop_offers().is_empty(), "new run must reset all transaction state"):
		return
	print("PASS: forge validation, fees, atomic consumption, persistent reward, claiming and new-run reset")
	get_tree().quit(0)


func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("FORGE TEST FAILED: " + message)
		get_tree().quit(1)
	return ok
