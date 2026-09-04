extends Node

const TIP_SCENE := preload("res://scene/shop/equipment_tip.tscn")
const CARD_SCENE := preload("res://scene/shop/equipment_card.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameConfig._init()
	if not await _test_tip_builds_all_configured_content():
		return
	if not await _test_tip_size_wraps_dynamic_content():
		return
	if not _test_tip_position_avoids_card_and_viewport_edges():
		return
	if not await _test_card_hides_tip_while_dragging():
		return
	if not await _test_card_tip_uses_its_canvas_layer():
		return
	get_tree().quit(0)


func _test_tip_builds_all_configured_content() -> bool:
	var tip := TIP_SCENE.instantiate() as EquipmentTip
	add_child(tip)
	await get_tree().process_frame
	tip.setup(Equipment.new(2), Vector2(48.0, 96.0))
	await get_tree().process_frame
	if not _assert(tip.icon.size == Vector2(48.0, 96.0), "tip icon should match the card sprite size"):
		return false
	if not _assert(tip.type_list.get_child_count() == 1, "tip should display the equipment effect type"):
		return false
	if not _assert(
		(tip.type_list.get_child(0) as Label).text == "发射武器",
		"effect type should use editable display configuration"
	):
		return false
	if not _assert(
		tip.attr_list.get_child_count() == 6,
		"tip should include numeric and enum-valued equipment attributes"
	):
		return false
	var texts: Array[String] = []
	for child: Label in tip.attr_list.get_children():
		texts.append(child.text)
	return _assert(
		texts.has("旋转环形发射") and texts.has("普通子弹") and texts.has("攻击力 +20"),
		"attribute labels should support exact enum descriptions and value templates"
	)


func _test_tip_size_wraps_dynamic_content() -> bool:
	var tip := TIP_SCENE.instantiate() as EquipmentTip
	add_child(tip)
	await get_tree().process_frame
	tip.setup(Equipment.new(2), Vector2(48.0, 96.0))
	await get_tree().process_frame
	await get_tree().process_frame
	var content_bottom := tip.attr_list.position.y + tip.attr_list.size.y
	if not _assert(tip.size.y >= content_bottom + tip.content_padding.y, "tip height should wrap every attribute"):
		return false
	return _assert(tip.bg.size == tip.size, "background should fill the dynamically sized tip")


func _test_tip_position_avoids_card_and_viewport_edges() -> bool:
	var tip_size := Vector2(240.0, 360.0)
	var viewport_size := Vector2(800.0, 600.0)
	var left_card := Rect2(10.0, 500.0, 96.0, 80.0)
	var left_result := EquipmentTip.calculate_position(left_card, tip_size, viewport_size, 12.0)
	if not _assert(left_result.x >= left_card.end.x, "tip should move right when it cannot fit on the left"):
		return false
	if not _assert(left_result.y + tip_size.y <= viewport_size.y, "tip should stay above the viewport bottom"):
		return false
	var right_card := Rect2(700.0, -20.0, 80.0, 80.0)
	var right_result := EquipmentTip.calculate_position(right_card, tip_size, viewport_size, 12.0)
	if not _assert(right_result.x + tip_size.x <= right_card.position.x, "tip should use the left side near the right edge"):
		return false
	return _assert(right_result.y >= 0.0, "tip should stay below the viewport top")


func _test_card_hides_tip_while_dragging() -> bool:
	var holder := Control.new()
	add_child(holder)
	var card := CARD_SCENE.instantiate() as EquipmentCard
	holder.add_child(card)
	card.setup(1)
	await get_tree().process_frame
	card.tooltip_delay = 0.01
	card._on_mouse_enter()
	await get_tree().create_timer(0.02).timeout
	await get_tree().process_frame
	if not _assert(card.get_equipment_tip() != null, "hovering should show a tip after the configured delay"):
		return false
	card._on_drag_start(Vector2.ZERO)
	return _assert(card.get_equipment_tip() == null, "starting a drag should hide the tip")


func _test_card_tip_uses_its_canvas_layer() -> bool:
	var canvas_layer := CanvasLayer.new()
	add_child(canvas_layer)
	var holder := Control.new()
	canvas_layer.add_child(holder)
	var card := CARD_SCENE.instantiate() as EquipmentCard
	holder.add_child(card)
	card.setup(1)
	await get_tree().process_frame
	card.tooltip_delay = 0.01
	card._on_mouse_enter()
	await get_tree().create_timer(0.02).timeout
	await get_tree().process_frame
	var tip := card.get_equipment_tip()
	if not _assert(tip != null, "a card inside a CanvasLayer should create its tip"):
		return false
	return _assert(
		tip.get_parent() == canvas_layer,
		"tip should share the card CanvasLayer so the game UI cannot cover it"
	)


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("EQUIPMENT TIP TEST FAILED: %s" % message)
	get_tree().quit(1)
	return false
