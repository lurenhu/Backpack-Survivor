extends Node

const FIXTURE := preload("res://tests/backpack/inventory_test_fixture.gd")
const CARD := preload("res://scene/shop/equipment_card.tscn")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	FIXTURE.reset(4, 4)
	var result := BackpackManager.grant_equipment(1, BackpackManager.GridType.PACKAGE, Vector2i.ZERO)
	var id := result.added_ids[0]
	var source := BackpackManager.get_equipment(id)
	var container := Control.new()
	add_child(container)
	var card := CARD.instantiate() as EquipmentCard
	container.add_child(card)
	card.setup_by_equipment(source)
	card._on_drag_start(Vector2.ZERO)
	card._on_rotate()
	if not _check(card.equipment.rotate_times == 1 and BackpackManager.get_equipment(id).rotate_times == 0, "drag rotation must only change the display snapshot"):
		return
	card.finish_drag()
	card.return_to_origin()
	if not _check(card.equipment.rotate_times == 0, "cancelled drag must restore displayed rotation"):
		return
	result = BackpackManager.try_move_equipment(id, BackpackManager.GridType.PACKAGE, Vector2i(0, 1))
	if not _check(result.success and BackpackManager.backpack_grid[0][0] == 0 and BackpackManager.backpack_grid[2][0] == 1, "overlapping move must ignore only its own previous cells"):
		return
	var before := BackpackManager.backpack_grid
	result = BackpackManager.try_move_equipment(id, BackpackManager.GridType.PACKAGE, Vector2i(3, 3))
	if not _check(not result.success and before == BackpackManager.backpack_grid and BackpackManager.get_equipment(id).grid_pos == Vector2i(0, 1), "out of bounds must not change position or occupancy"):
		return
	BackpackManager.grant_equipment(12, BackpackManager.GridType.STAGE, Vector2i(1, 0))
	result = BackpackManager.try_move_equipment(id, BackpackManager.GridType.STAGE, Vector2i.ZERO, 1)
	if not _check(not result.success and BackpackManager.get_equipment(id).state == BackpackManager.GridType.PACKAGE, "cross-grid collision must preserve source"):
		return
	result = BackpackManager.try_move_equipment(id, BackpackManager.GridType.STAGE, Vector2i(0, 1), 1)
	if not _check(result.success and BackpackManager.backpack_equip.is_empty() and BackpackManager.get_equipment(id).shape == [[1, 1]], "cross-grid rotated move must preserve instance and update shape"):
		return
	var snapshot := BackpackManager.get_equipment(id)
	snapshot.rotate_clockwise()
	if not _check(BackpackManager.get_equipment(id).rotate_times == 1, "equipment snapshots cannot mutate formal rotation"):
		return
	var selection := BackpackManager.try_select_forge_material(id, Vector2i.ZERO, 1)
	result = BackpackManager.try_move_equipment(id, BackpackManager.GridType.PACKAGE, Vector2i.ZERO)
	if not _check(selection.success and not result.success and result.reason == &"material_reserved", "selected materials must reject moves"):
		return
	BackpackManager.cancel_forge_material(id)
	result = BackpackManager.try_move_equipment(id, BackpackManager.GridType.PACKAGE, Vector2i.ZERO)
	if not _check(result.success and BackpackManager.get_equipment(id).instance_id == id, "cancelling selection must unlock the same item"):
		return
	BackpackManager.init_backpack(1)
	if not _check(not BackpackManager.try_move_equipment(id, BackpackManager.GridType.STAGE, Vector2i.ZERO).success, "old instance requests must not affect a new run"):
		return
	container.queue_free()
	await get_tree().process_frame
	print("PASS: preview isolation, overlapping moves, rotations, collisions, reservations and stale instances")
	get_tree().quit(0)


func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("MOVE TEST FAILED: " + message)
		get_tree().quit(1)
	return ok
