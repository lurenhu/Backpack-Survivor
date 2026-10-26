extends Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameState._initialize_run(1)
	var gaming := preload("res://scene/main/gaming.tscn").instantiate()
	add_child(gaming)
	var panel := gaming.get_node("PanelManager") as PanelManager
	if not await _wait_for_panels(panel):
		return
	var map_view := panel.map.get_child(0) as Map
	var shop := map_view._find_button(0, 0)
	shop.button.pressed.emit()
	shop.button.pressed.emit()
	await get_tree().create_timer(0.2).timeout
	if not _check(GameState.phase == RunState.Phase.MAP and panel.map.visible and not shop.node.visited and float(shop.bg_texture.material.get_shader_parameter("progress")) > 0, "shop must remain on the map while its click animation plays"):
		return
	await get_tree().create_timer(0.4).timeout
	if not _check(panel.panel_animation.current_animation == "hide_map" and not panel.shop.visible, "map hide must run before shop show"):
		return
	if not await _wait_for_panels(panel):
		return
	if not _check(GameState.phase == RunState.Phase.SHOP and panel.shop.visible and not panel.map.visible and shop.node.visited, "shop must open only after its animation finishes"):
		return
	GameState.leave_current_node()
	if not await _wait_for_panels(panel):
		return
	var forge := map_view._find_button(1, 1)
	var battle := map_view._find_button(1, 0)
	forge.button.pressed.emit()
	battle.button.pressed.emit()
	await get_tree().create_timer(0.2).timeout
	if not _check(GameState.phase == RunState.Phase.MAP and not forge.node.visited and not battle.node.visited, "another reachable node cannot interrupt an active selection"):
		return
	await get_tree().create_timer(0.4).timeout
	if not _check(panel.panel_animation.current_animation == "hide_map" and not panel.forge.visible, "map hide must run before forge show"):
		return
	if not await _wait_for_panels(panel):
		return
	if not _check(GameState.phase == RunState.Phase.FORGE and panel.forge.visible and not battle.node.visited and not CombatManager.is_battle_active, "forge must open after its animation without starting the other node"):
		return
	GameState.leave_current_node()
	if not await _wait_for_panels(panel):
		return
	var next_shop := map_view._find_button(2, 0)
	var config_id := next_shop.node.config_id
	next_shop.node.config_id = -1
	next_shop.button.pressed.emit()
	await get_tree().create_timer(0.6).timeout
	if not _check(GameState.phase == RunState.Phase.MAP and not next_shop.node.visited and not next_shop.button.disabled and is_zero_approx(float(next_shop.bg_texture.material.get_shader_parameter("progress"))), "a rejected request must restore the button without consuming progress"):
		return
	next_shop.node.config_id = config_id
	next_shop.button.pressed.emit()
	GameState._initialize_run(2)
	await get_tree().create_timer(0.6).timeout
	if not _check(GameState.phase == RunState.Phase.MAP and GameState.current_character_id == 2 and MapManager.current_map_node == null, "an old animation must not enter a node in a new run"):
		return
	gaming.free()
	print("PASS: shop/forge animation before navigation, duplicate and competing clicks, rejected entry recovery and stale animation isolation")
	get_tree().quit(0)


func _wait_for_panels(panel: PanelManager) -> bool:
	for attempt in 180:
		if not panel.is_switching_panels:
			return true
		await get_tree().create_timer(0.02).timeout
	return _check(false, "panel transition timed out")


func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("MAP SELECTION TEST FAILED: " + message)
		get_tree().quit(1)
	return ok
