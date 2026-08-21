extends Node

const PLAYER_SCENE := preload("res://scene/battle/entities/player.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameConfig._init()
	if not _test_attribute_container():
		return
	if not _test_equipment_type_parsing():
		return
	if not await _test_rotate_equipment():
		return
	if not await _test_shooter_equipment():
		return
	get_tree().quit(0)


func _test_attribute_container() -> bool:
	var glove_a := Equipment.new(23)
	var glove_b := Equipment.new(23)
	var container := AttributeContainer.new()
	container.add_modifier(AttributeModifier.new(glove_a, AttrType.Type.ROTATE_SPEED, 0.5))
	container.add_modifier(AttributeModifier.new(glove_a, AttrType.Type.ROTATE_SPEED_PER, 0.1))
	container.add_modifier(AttributeModifier.new(glove_b, AttrType.Type.ROTATE_SPEED_PER, 0.1))
	if not _assert(is_equal_approx(container.calculate(3.0, AttrType.Type.ROTATE_SPEED, AttrType.Type.ROTATE_SPEED_PER), 4.2), "fixed and percent modifiers should use the agreed formula"):
		return false
	container.remove_by_source(glove_a)
	return _assert(is_equal_approx(container.calculate(3.0, AttrType.Type.ROTATE_SPEED, AttrType.Type.ROTATE_SPEED_PER), 3.3), "same-ID equipment references should be independent")


func _test_equipment_type_parsing() -> bool:
	if not _assert(
		EquipmentEffectType.from_string("JEWELRY") == EquipmentEffectType.Type.ROTATE,
		"legacy jewelry behavior should remain rotate"
	):
		return false
	if not _assert(
		int(EquipmentEffectType.from_string("TYPO")) == -1,
		"unknown equipment type should not become a rotate weapon"
	):
		return false
	if not _assert(
		EquipmentEffectFactory.create_effect(EquipmentEffectType.from_string("TYPO")) == null,
		"factory should reject unknown equipment types"
	):
		return false
	return true


func _test_rotate_equipment() -> bool:
	GameState.current_character_id = 1
	BackpackManager.init_backpack(1)
	if not _assert(BackpackManager.equipments.size() == 2, "warrior should start with two equipment items"):
		return false

	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	await get_tree().process_frame

	if not _assert(player.get_node_or_null("Components/EquipmentHost") != null, "missing EquipmentHost"):
		return false
	if not _assert(player.get_node_or_null("EquipmentEntities/WeaponAnchor") != null, "missing WeaponAnchor"):
		return false
	if not _assert(player.get_node_or_null("EquipmentEntities/ShooterAnchor") != null, "missing ShooterAnchor"):
		return false
	if not _assert(
		player.get_node("EquipmentEntities/WeaponAnchor").get_child_count() == 2,
		"two initial rotate weapons were not created"
	):
		return false
	var equipment_host := player.get_node("Components/EquipmentHost") as EquipmentHost
	equipment_host.cleanup()
	await get_tree().process_frame
	if not _assert(
		player.get_node("EquipmentEntities/WeaponAnchor").get_child_count() == 0,
		"cleanup should remove rotate entities while Player remains alive"
	):
		return false
	equipment_host.cleanup()
	var context := EquipmentContext.new().setup(
		player,
		player.get_node("EquipmentEntities/WeaponAnchor"),
		player.get_node("EquipmentEntities/ShooterAnchor")
	)
	equipment_host.initialize(BackpackManager.equipments.values(), context)
	if not _assert(
		player.get_node("EquipmentEntities/WeaponAnchor").get_child_count() == 2,
		"reinitialize should recreate exactly two rotate entities"
	):
		return false

	player.queue_free()
	await get_tree().process_frame
	return true


func _test_shooter_equipment() -> bool:
	GameState.current_character_id = 2
	BackpackManager.init_backpack(2)
	if not _assert(BackpackManager.equipments.size() == 2, "mage should start with two equipment items"):
		return false

	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	await get_tree().process_frame
	var shooter_anchor := player.get_node("EquipmentEntities/ShooterAnchor")
	if not _assert(shooter_anchor.get_child_count() == 1, "duplicate shooter equipment should create one Shooter"):
		return false

	var shooter := shooter_anchor.get_child(0) as Shooter
	if not _assert(shooter._shoot_num == 2, "duplicate shooter equipment should produce two projectiles"):
		return false

	player.queue_free()
	await get_tree().process_frame
	return true


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	printerr("equipment_runtime_test: ", message)
	get_tree().quit(1)
	return false
