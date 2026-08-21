extends Node

const PLAYER_SCENE := preload("res://scene/battle/entities/player.tscn")
const ENEMY_SHOOTER_SCENE := preload("res://scene/battle/entities/enemy_skeleton.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameConfig._init()
	if not _test_backpack_equipment_attributes():
		return
	if not _test_equipment_type_parsing():
		return
	if not await _test_enemy_shooter_timer():
		return
	if not await _test_rotate_equipment():
		return
	if not await _test_shooter_equipment():
		return
	get_tree().quit(0)


func _test_backpack_equipment_attributes() -> bool:
	var original_backpack_equip := BackpackManager.backpack_equip.duplicate()
	var glove_a := Equipment.new(23)
	var glove_b := Equipment.new(23)
	BackpackManager.backpack_equip = {
		Vector2i(0, 0): glove_a,
		Vector2i(1, 0): glove_b,
	}
	BackpackManager.recalculate_equipment_attrs()
	if not _assert(
		is_equal_approx(BackpackManager.equipment_attrs.get_value(AttrType.Type.ATK), 20.0),
		"two passive items should aggregate attack"
	):
		return false
	if not _assert(
		is_equal_approx(BackpackManager.equipment_attrs.get_value(AttrType.Type.ROTATE_SPEED_PER), 0.4),
		"two passive items should aggregate rotate speed percentage"
	):
		return false

	BackpackManager.backpack_equip.erase(Vector2i(0, 0))
	BackpackManager.recalculate_equipment_attrs()
	if not _assert(
		is_equal_approx(BackpackManager.equipment_attrs.get_value(AttrType.Type.ATK), 10.0),
		"full rebuild should remove absent passive equipment"
	):
		return false

	BackpackManager.backpack_equip[Vector2i(2, 0)] = Equipment.new(1)
	BackpackManager.recalculate_equipment_attrs()
	if not _assert(
		is_equal_approx(BackpackManager.equipment_attrs.get_value(AttrType.Type.ATK), 10.0),
		"entity equipment attributes should not enter the passive aggregate"
	):
		return false

	BackpackManager.backpack_equip.clear()
	BackpackManager.recalculate_equipment_attrs()
	if not _assert(
		not BackpackManager.equipment_attrs.has(AttrType.Type.ATK),
		"empty backpack should clear previous aggregate values"
	):
		return false

	BackpackManager.backpack_equip = original_backpack_equip
	BackpackManager.init_backpack(1)
	var observed_attack := {"value": -1.0}
	var on_changed := func() -> void:
		observed_attack.value = (
			BackpackManager.equipment_attrs.get_value(AttrType.Type.ATK)
			if BackpackManager.equipment_attrs.has(AttrType.Type.ATK)
			else 0.0
		)
	BackpackManager.equip_changed.connect(on_changed, CONNECT_ONE_SHOT)
	var signal_glove := Equipment.new(11)
	signal_glove.state = BackpackManager.GridType.PACKAGE
	var position := BackpackManager.find_position(signal_glove.shape, BackpackManager.backpack_grid)
	signal_glove.grid_pos = position
	if not _assert(BackpackManager.add_to_equip_grid(signal_glove, position), "signal-order glove should fit in backpack"):
		return false
	return _assert(
		is_equal_approx(observed_attack.value, 10.0),
		"equip_changed listeners should observe rebuilt attributes"
	)


func _test_equipment_type_parsing() -> bool:
	if not _assert(
		EquipmentEffectType.from_string("JEWELRY") == EquipmentEffectType.Type.PASSIVE_ATTRIBUTE,
		"legacy jewelry should map to passive attributes"
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


func _test_enemy_shooter_timer() -> bool:
	var enemy := ENEMY_SHOOTER_SCENE.instantiate() as EnemyShooter
	enemy.setup(3)
	add_child(enemy)
	if not _assert(enemy.shooter.shoot_timer.is_stopped(), "enemy shooter setup should stop its automatic timer"):
		return false
	enemy.queue_free()
	await get_tree().process_frame
	return true


func _test_rotate_equipment() -> bool:
	GameState.current_character_id = 1
	BackpackManager.init_backpack(1)
	if not _assert(BackpackManager.equipments.size() == 2, "warrior should start with two equipment items"):
		return false
	var glove_a := Equipment.new(23)
	var glove_b := Equipment.new(23)
	BackpackManager.backpack_equip[Vector2i(10, 0)] = glove_a
	BackpackManager.backpack_equip[Vector2i(11, 0)] = glove_b
	BackpackManager.recalculate_equipment_attrs()

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
	var weapon_anchor := player.get_node("EquipmentEntities/WeaponAnchor")
	var first_weapon := weapon_anchor.get_child(0) as RotateWeapon
	var second_weapon := weapon_anchor.get_child(1) as RotateWeapon
	for weapon in [first_weapon, second_weapon]:
		if not _assert(is_equal_approx(weapon._attack_power, 25.0), "global attack should apply when rotate weapons are created"):
			return false
		if not _assert(is_equal_approx(weapon._rotation_speed, 14.0), "all rotate weapons should read the backpack speed bonus"):
			return false

	BackpackManager.backpack_equip.erase(Vector2i(10, 0))
	BackpackManager.recalculate_equipment_attrs()
	BackpackManager.equip_changed.emit()
	if not _assert(weapon_anchor.get_child(0) == first_weapon and weapon_anchor.get_child(1) == second_weapon, "modifier removal should not recreate rotate weapons"):
		return false
	for weapon in [first_weapon, second_weapon]:
		if not _assert(is_equal_approx(weapon._attack_power, 15.0), "removing one glove should refresh rotate weapon attack"):
			return false
		if not _assert(is_equal_approx(weapon._rotation_speed, 12.0), "removing one glove should refresh rotate weapon speed"):
			return false

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
	BackpackManager.backpack_equip[Vector2i(10, 0)] = Equipment.new(23)
	BackpackManager.backpack_equip[Vector2i(11, 0)] = Equipment.new(23)
	BackpackManager.recalculate_equipment_attrs()

	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	await get_tree().process_frame
	var shooter_anchor := player.get_node("EquipmentEntities/ShooterAnchor")
	if not _assert(shooter_anchor.get_child_count() == 1, "duplicate shooter equipment should create one Shooter"):
		return false

	var shooter := shooter_anchor.get_child(0) as Shooter
	if not _assert(shooter._shoot_num == 2, "duplicate shooter equipment should produce two projectiles"):
		return false
	if not _assert(is_equal_approx(shooter.shoot_timer.wait_time, 0.5), "shooter timer should use the configured interval"):
		return false
	if not _assert(
		shooter.shoot_timer.time_left > 0.0 and shooter.shoot_timer.time_left <= 0.5,
		"equipment shooter should restart its active countdown with the configured interval"
	):
		return false

	if not _assert(is_equal_approx(shooter._bullet_damage, 40.0), "global attack should apply when equipment shooter is created"):
		return false
	if not _assert(is_equal_approx(shooter.shoot_timer.wait_time, 0.5), "rotation modifiers should not change shooter timing"):
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
