extends Node

var _events: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameState._initialize_run(1)
	var panel := preload("res://scene/shop/panel_manager.tscn").instantiate() as PanelManager
	add_child(panel)
	panel.panel_animation.speed_scale = 10.0
	panel.panel_animation.animation_started.connect(func(animation: StringName): _events.append("start:" + animation))
	panel.panel_animation.animation_finished.connect(func(animation: StringName): _events.append("finish:" + animation))
	if not await _wait_for_panels(panel):
		return
	_events.clear()
	panel.present_phase(RunState.Phase.SHOP)
	panel.present_phase(RunState.Phase.SHOP)
	if not _check(panel.panel_animation.current_animation == "hide_map" and not panel.shop.visible and panel._input_blocker.visible, "map must hide with input blocked before shop appears"):
		return
	if not await _wait_for_panels(panel) or not _expect(["start:hide_map", "finish:hide_map", "start:show_shop", "finish:show_shop"]):
		return
	if not _check(panel.shop.visible and panel.package.visible and not panel.map.visible and not panel._input_blocker.visible, "shop and package must be visible after transition"):
		return
	_events.clear()
	panel.present_phase(RunState.Phase.MAP)
	panel.present_phase(RunState.Phase.FORGE)
	if not await _wait_for_panels(panel) or not _expect(["start:hide_shop", "finish:hide_shop", "start:show_forge", "finish:show_forge"]):
		return
	_events.clear()
	panel.present_phase(RunState.Phase.MAP)
	if not await _wait_for_panels(panel) or not _expect(["start:hide_forge", "finish:hide_forge", "start:show_map", "finish:show_map"]):
		return
	# 转场中途离开页面，不能在 hide 结束后重新打开过期目标。
	_events.clear()
	panel.present_phase(RunState.Phase.SHOP)
	panel.present_phase(RunState.Phase.TRANSITIONING)
	if not await _wait_for_panels(panel) or not _expect(["start:hide_map", "finish:hide_map"]):
		return
	if not _check(not panel.map.visible and not panel.shop.visible and not panel.forge.visible and not panel.package.visible, "scene exit must leave no stale panel visible"):
		return
	# show 已开始时的新请求必须等它完成，再 hide 当前面板。
	_events.clear()
	panel.present_phase(RunState.Phase.SHOP)
	panel.present_phase(RunState.Phase.MAP)
	if not await _wait_for_panels(panel) or not _expect(["start:show_shop", "finish:show_shop", "start:hide_shop", "finish:hide_shop", "start:show_map", "finish:show_map"]):
		return
	panel.present_phase(RunState.Phase.FORGE)
	panel.free()
	await get_tree().process_frame
	print("PASS: ordered hide/show, duplicate requests, latest target, input blocking and scene exit during animation")
	get_tree().quit(0)


func _wait_for_panels(panel: PanelManager) -> bool:
	for attempt in 100:
		await get_tree().create_timer(0.02).timeout
		if not panel.is_switching_panels:
			return true
	return _check(false, "panel transition timed out")


func _expect(expected: Array) -> bool:
	return _check(_events == expected, "animation order: expected %s, got %s" % [expected, _events])


func _check(ok: bool, message: String) -> bool:
	if not ok:
		push_error("PANEL ANIMATION TEST FAILED: " + message)
		get_tree().quit(1)
	return ok
