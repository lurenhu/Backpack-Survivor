extends Node

const PACKAGE_LABEL_SCENE := preload("res://scene/shop/package_label.tscn")
const PACKAGE_SCENE := preload("res://scene/shop/package.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if not await _test_package_label_uses_configurable_float_animation():
		return
	if not await _test_purchasable_grid_hover_shows_cost_at_cell_center():
		return
	get_tree().quit(0)


func _test_package_label_uses_configurable_float_animation() -> bool:
	var label := PACKAGE_LABEL_SCENE.instantiate() as Label
	add_child(label)
	label.position = Vector2(10.0, 30.0)
	label.float_distance = 20.0
	label.fade_duration = 0.02
	label.show_cost(40)
	if not _assert(label.text == "40", "package label should display the supplied grid cost"):
		return false
	label.play_purchase_animation()
	await get_tree().create_timer(0.04).timeout
	await get_tree().process_frame
	return _assert(
		not is_instance_valid(label) or label.is_queued_for_deletion(),
		"purchase label should float, fade, and free itself"
	)


func _test_purchasable_grid_hover_shows_cost_at_cell_center() -> bool:
	BackpackManager._inventory.grids[BackpackManager.GridType.PACKAGE] = [[0, -1]]
	BackpackManager._inventory.grids[BackpackManager.GridType.STAGE] = []
	BackpackManager._inventory.grid_cost = 10
	BackpackManager.set_grid_purchase_mode(true)
	var package := PACKAGE_SCENE.instantiate() as Package
	add_child(package)
	await get_tree().process_frame
	var cell_center := package.backpack_grid_tile.to_global(
		package.backpack_grid_tile.map_to_local(Vector2i(1, 0))
	)
	package._update_grid_purchase_hover(cell_center)
	var label := package.find_child("PackageLabel", true, false) as Label
	if not _assert(label != null, "hovering a purchasable grid should create a package label"):
		return false
	if not _assert(label.text == "10", "hover label should show the current grid cost"):
		return false
	if not _assert(
		label.get_global_rect().has_point(cell_center),
		"hover label should be centered over the purchasable grid"
	):
		return false
	package._update_grid_purchase_hover(Vector2(-100.0, -100.0))
	await get_tree().process_frame
	if not _assert(
		package.find_child("PackageLabel", true, false) == null,
		"leaving purchasable grids should hide the package label"
	):
		return false
	package.queue_free()
	BackpackManager.set_grid_purchase_mode(false)
	return true


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("PACKAGE LABEL TEST FAILED: %s" % message)
	get_tree().quit(1)
	return false
