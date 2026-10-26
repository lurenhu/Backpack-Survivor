extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	GameConfig.ensure_loaded()
	var staff := GameConfig.equipment.get(2) as EquipmentData
	if not _assert(
		staff != null
		and ShooterType.from_attr(staff.attr) == ShooterType.Type.ROTATING_RADIAL,
		"staff equipment should load as ROTATING_RADIAL from equipments.csv"
	):
		return
	var legacy := _equipment("ATK:10,BULLET_SPEED:200,SHOOT_INTERVAL:0.5")
	if not _assert(
		ShooterType.from_attr(legacy.attr) == ShooterType.Type.TARGETING,
		"legacy shooter should default to TARGETING"
	):
		return
	var legacy_spec := ProjectileSpecFactory.from_equipment(
		legacy,
		ProjectileSpec.Faction.PLAYER
	)
	if not _assert(
		legacy_spec != null and legacy_spec.bullet_type == BulletType.Type.NORMAL,
		"legacy shooter should default to NORMAL bullets"
	):
		return

	var configured := _equipment(
		"SHOOTER_TYPE:ROTATING_RADIAL,BULLET_TYPE:PIERCING,ATK:15,"
		+ "BULLET_SPEED:500,PENETRATION_COUNT:2,EXPLOSION_DAMAGE:20,"
		+ "EXPLOSION_RADIUS:100,SHOOT_NUM:3"
	)
	var spec := ProjectileSpecFactory.from_equipment(
		configured,
		ProjectileSpec.Faction.PLAYER
	)
	if not _assert(
		ShooterType.from_attr(configured.attr) == ShooterType.Type.ROTATING_RADIAL,
		"ROTATING_RADIAL should be parsed"
	):
		return
	if not _assert(
		spec != null
		and spec.bullet_type == BulletType.Type.PIERCING
		and spec.direct_damage == 15.0
		and spec.speed == 500.0
		and spec.max_hit_count == 2
		and spec.explosion_damage == 20.0
		and spec.explosion_radius == 100.0
		and spec.shot_count == 3,
		"projectile spec should copy all configured values"
	):
		return

	if not _assert(
		ShooterType.from_string("invalid") == ShooterType.Type.UNKNOWN,
		"unknown shooter types should be rejected"
	):
		return
	if not _assert(
		BulletType.from_string("invalid") == BulletType.Type.UNKNOWN,
		"unknown bullet types should be rejected"
	):
		return
	if not _test_invalid_bullet_type_skips_effect():
		return

	var snapshot := spec.snapshot()
	spec.direct_damage = 99.0
	if not _assert(
		snapshot.direct_damage == 15.0,
		"a projectile snapshot should not change with its source spec"
	):
		return

	get_tree().quit(0)


func _test_invalid_bullet_type_skips_effect() -> bool:
	var coordinator := ShooterRingCoordinator.new()
	var player := preload("res://scene/battle/entities/player.tscn").instantiate() as Player
	var context := EquipmentContext.new()
	context.player = player
	context.shooter_ring_coordinator = coordinator
	var effect := ShooterEffect.new()
	var invalid := _equipment("SHOOTER_TYPE:RADIAL,BULLET_TYPE:INVALID,BULLET_SPEED:100")
	var source: Equipment = Equipment.new(2)
	effect.setup(context, invalid, [source])
	effect.activate()
	var skipped := coordinator.get_rings().is_empty()
	effect.cleanup()
	player.free()
	coordinator.free()
	return _assert(skipped, "an invalid BULLET_TYPE should not create a shooter ring")


func _equipment(attr: String) -> EquipmentData:
	return EquipmentData.from_dict({
		"ID": 99,
		"Name": "test shooter",
		"Shape": "1",
		"Rarity": 0,
		"Attr": attr,
		"Price": 1,
		"Source": "",
		"Type": "SHOOTER",
	})


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("PROJECTILE TYPE TEST FAILED: %s" % message)
	get_tree().quit(1)
	return false
