extends Node

const PLAYER_SCENE := preload("res://scene/battle/entities/player.tscn")
const ENEMY_SHOOTER_SCENE := preload("res://scene/battle/entities/enemy_skeleton.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameConfig._init()
	if "--area-only" in OS.get_cmdline_user_args():
		if not _test_equipment_type_parsing():
			return
		if not _test_area_effect_factory():
			return
		if not await _test_area_equipment():
			return
		get_tree().quit(0)
		return
	if not _test_backpack_equipment_attributes():
		return
	if not _test_equipment_type_parsing():
		return
	if not _test_area_effect_factory():
		return
	if not await _test_area_equipment():
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
		is_equal_approx(BackpackManager.equipment_attrs.get_value(AttrType.Type.ROTATE_SPEED_GAIN), 0.4),
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
	var observed_attack := {"value": - 1.0}
	var on_changed := func() -> void:
		observed_attack.value = (
			BackpackManager.equipment_attrs.get_value(AttrType.Type.ATK)
			if BackpackManager.equipment_attrs.has(AttrType.Type.ATK)
			else 0.0
		)
	BackpackManager.equip_changed.connect(on_changed, CONNECT_ONE_SHOT)
	var signal_glove := Equipment.new(12)
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
		EquipmentEffectType.from_string("AREA") == EquipmentEffectType.Type.AREA,
		"area equipment type should be parsed"
	):
		return false
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


func _test_area_effect_factory() -> bool:
	return _assert(
		EquipmentEffectFactory.create_effect(EquipmentEffectType.Type.AREA) != null,
		"factory should create area equipment effects"
	)


func _test_area_equipment() -> bool:
	GameState.current_character_id = 1
	BackpackManager.init_backpack(1)
	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	await get_tree().process_frame
	var area_anchor := player.get_node("EquipmentEntities/AreaAnchor") as Node2D
	if not _assert(area_anchor != null, "player should expose AreaAnchor"):
		return false

	var data := EquipmentData.from_dict({
		"ID": 99,
		"Name": "test area weapon",
		"Shape": "1",
		"Attr": "ATK:12,AREA_RADIUS:80,AREA_INTERVAL:0.05",
		"Type": "AREA",
	})
	var context := EquipmentContext.new().setup(
		player,
		player.weapon_anchor,
		player.shooter_anchor,
		area_anchor
	)
	var effect := EquipmentEffectFactory.create_effect(data.type)
	effect.setup(context, data, [Equipment.new(1), Equipment.new(1)])
	effect.activate()
	await get_tree().physics_frame

	if not _assert(area_anchor.get_child_count() == 2, "each area equipment should create one AreaWeapon"):
		return false
	var area_weapon := area_anchor.get_child(0) as AreaWeapon
	var circle := area_weapon.collision_shape_2d.shape as CircleShape2D
	if not _assert(is_equal_approx(circle.radius, 80.0), "area weapon should use configured radius"):
		return false
	if not _assert(is_equal_approx(area_weapon.damage_timer.wait_time, 0.05), "area weapon should use configured interval"):
		return false

	var enemy := ENEMY_SHOOTER_SCENE.instantiate() as EnemyShooter
	enemy.setup(3)
	add_child(enemy)
	enemy.global_position = area_weapon.global_position
	await get_tree().physics_frame
	await get_tree().physics_frame
	var observed_damage := {"count": 0, "amount": 0.0}
	var on_damage := func(result: DamageResult) -> void:
		if result.target == enemy:
			observed_damage.count += 1
			observed_damage.amount = result.actual_damage
	if not _assert(preload("res://tests/battle/battle_test_context.gd").start(self), "battle must start"):
		return false
	CombatManager.damage_applied.connect(on_damage)
	var previous_hp := enemy.current_hp
	area_weapon._on_damage_timer_timeout()
	CombatManager.damage_applied.disconnect(on_damage)
	CombatManager.end_battle(true)
	if not _assert(observed_damage.count == 1, "area tick should damage every overlapping enemy once"):
		return false
	if not _assert(is_equal_approx(observed_damage.amount, 12.0), "area tick should use configured attack"):
		return false
	if not _assert(is_equal_approx(previous_hp - enemy.current_hp, 12.0), "area damage should reduce health without a HUD"):
		return false

	effect.cleanup()
	enemy.queue_free()
	await get_tree().process_frame
	if not _assert(area_anchor.get_child_count() == 0, "area effect cleanup should remove its entities"):
		return false
	player.queue_free()
	await get_tree().process_frame
	return true


func _test_enemy_shooter_timer() -> bool:
	if not _assert(preload("res://tests/battle/battle_test_context.gd").start(self), "battle must start"):
		return false
	var enemy := ENEMY_SHOOTER_SCENE.instantiate() as EnemyShooter
	enemy.setup(3)
	add_child(enemy)
	if not _assert(enemy.shooter is TargetingShooter, "enemy shooter should use TargetingShooter"):
		return false
	if not _assert(enemy.shooter.shoot_timer.is_stopped(), "enemy shooter setup should stop its automatic timer"):
		return false
	var other_enemy := ENEMY_SHOOTER_SCENE.instantiate() as EnemyShooter
	other_enemy.setup(3)
	add_child(other_enemy)
	var requests: Array[ProjectileSpawnRequest] = []
	var on_projectile := func(request: ProjectileSpawnRequest) -> void:
		requests.append(request)
	CombatManager.projectile_requested.connect(on_projectile)
	enemy.shooter._on_shoot_timeout()
	if not _assert(requests.is_empty(), "enemy shooters should not auto-target other enemies"):
		return false
	var player := PLAYER_SCENE.instantiate() as Player
	player.position = Vector2(100.0, 0.0)
	enemy._player = player
	enemy.fire_bullet()
	CombatManager.projectile_requested.disconnect(on_projectile)
	if not _assert(
		requests.size() == 1
		and requests[0].spec.source_faction == ProjectileSpec.Faction.ENEMY,
		"enemy attack animations should request one enemy projectile"
	):
		return false
	player.free()
	other_enemy.queue_free()
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
	var coordinator := shooter_anchor.get_node("ShooterRingCoordinator") as ShooterRingCoordinator
	if not _assert(coordinator.get_rings().size() == 1, "one shooter equipment id should create one ring"):
		return false

	var ring := coordinator.get_rings()[0]
	if not _assert(ring.get_shooters().size() == 2, "two equipment copies should create two shooters"):
		return false
	var shooter := ring.get_shooters()[0]
	if not _assert(is_equal_approx(shooter.shoot_timer.wait_time, 0.5), "shooter timer should use the configured interval"):
		return false
	if not _assert(
		shooter.shoot_timer.time_left > 0.0 and shooter.shoot_timer.time_left <= 0.5,
		"equipment shooter should restart its active countdown with the configured interval"
	):
		return false

	if not _assert(is_equal_approx(shooter.spec.direct_damage, 40.0), "global attack should apply when equipment shooter is created"):
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
