extends Node

const PANEL_SCENE := preload("res://scene/shop/panel_manager.tscn")
const FIXTURE := preload("res://tests/backpack/inventory_test_fixture.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameState._initialize_run(1)
	FIXTURE.reset()
	var panel := _panel()
	var sword: Equipment = FIXTURE.add(1)
	var bow: Equipment = FIXTURE.add(3)
	var source := panel.package.backpack_cards[sword.grid_pos]
	_drop(source, panel.forge.forge_table_grid, Vector2i.ZERO)
	if not _check(panel.forge.table_cards.size() == 1 and source.mouse_filter == Control.MOUSE_FILTER_IGNORE, "selecting by drag must lock the original card and show a material preview"):
		return
	var material := panel.forge.table_cards[Vector2i.ZERO]
	_drop(material, panel.package.stage_container, Vector2i.ZERO)
	if not _check(panel.forge.table_cards.is_empty() and source.mouse_filter != Control.MOUSE_FILTER_IGNORE and BackpackManager.stage_equip.is_empty(), "dragging material back must cancel selection without duplicating or moving the original"):
		return
	_drop(source, panel.forge.forge_table_grid, Vector2i.ZERO)
	_drop(panel.package.backpack_cards[bow.grid_pos], panel.forge.forge_table_grid, Vector2i(1, 0))
	if not _check(panel.forge.result_equipment_card.visible and panel.forge.result_equipment_card.mouse_filter == Control.MOUSE_FILTER_IGNORE, "matching materials must display a non-claimable recipe preview"):
		return
	panel.forge.forge_button.pressed.emit()
	if not _check(BackpackManager.gold == 90 and panel.package.backpack_cards.is_empty() and panel.forge.table_cards.is_empty(), "forge button must atomically update all views and charge the configured fee"):
		return
	var reward_id := BackpackManager.get_pending_forge_reward().instance_id
	GameState._run.phase = RunState.Phase.FORGE
	panel.forge.exit_button.pressed.emit()
	panel.free()
	panel = _panel()
	if not _check(panel.forge.result_equipment_card.equipment.instance_id == reward_id and panel.forge.result_equipment_card.visible, "recreated panel must restore the pending result"):
		return
	_drop(panel.forge.result_equipment_card, panel.package.stage_container, Vector2i.ZERO)
	if not _check(BackpackManager.get_pending_forge_reward() == null and panel.package.stage_cards.size() == 1 and not panel.forge.result_equipment_card.visible, "dragging the result must transfer it exactly once and update both panels"):
		return
	# 同区域拖放仍使用相同实例，移动完成后卡牌位置采用正式快照。
	var reward_card := panel.package.stage_cards[Vector2i.ZERO]
	_drop(reward_card, panel.package.stage_container, Vector2i(1, 0))
	if not _check(panel.package.stage_cards.has(Vector2i(1, 0)) and BackpackManager.get_equipment(reward_id).grid_pos == Vector2i(1, 0), "inventory drag must update the live card index and formal position"):
		return
	panel.free()
	await get_tree().process_frame
	print("PASS: real card signals, material selection/cancel, forge button, panel recreation and reward drag")
	get_tree().quit(0)


func _panel() -> PanelManager:
	var panel := PANEL_SCENE.instantiate() as PanelManager
	add_child(panel)
	panel.panel_animation.advance(1.0)
	panel.panel_animation.stop()
	panel.package.position = Vector2.ZERO
	panel.forge.position = Vector2(650.0, 0.0)
	panel.shop.position = Vector2(1300.0, 0.0)
	return panel


func _drop(card: EquipmentCard, container: Control, pos: Vector2i) -> void:
	card._on_drag_start(card.global_position + card.pivot_offset)
	var target := container.global_position + Vector2(pos) * BackpackManager.CELL_SIZE + Vector2.ONE * 24.0
	card._on_drag_move(target)
	card.global_position = target - Vector2.ONE * 24.0
	card._on_drag_end()


func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("INVENTORY UI FLOW TEST FAILED: " + message)
		get_tree().quit(1)
	return ok
