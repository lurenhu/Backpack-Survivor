extends Node

const ENEMY_SCENE: PackedScene = preload("res://scene/battle/entities/enemy_slime.tscn")

var _requests: Array[ProjectileSpawnRequest] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _assert(preload("res://tests/battle/battle_test_context.gd").start(self), "battle must start"):
		return
	CombatManager.projectile_requested.connect(_on_projectile_requested)
	if not await _test_radial_direction():
		return
	if not await _test_targeting_uses_nearest_enemy():
		return
	if not await _test_ring_evenly_distributes_shooters():
		return
	if not await _test_coordinator_stably_layers_rings():
		return
	if not await _test_rotating_ring_keeps_spacing():
		return
	CombatManager.projectile_requested.disconnect(_on_projectile_requested)
	get_tree().quit(0)


func _test_radial_direction() -> bool:
	_requests.clear()
	var source := Node2D.new()
	var shooter := RadialShooter.new()
	add_child(source)
	source.add_child(shooter)
	shooter.position = Vector2(70.0, 0.0)
	shooter.setup(source, _spec(), 1.0)
	shooter._on_shoot_timeout()
	if not _assert(
		_requests.size() == 1 and _requests[0].direction.is_equal_approx(Vector2.RIGHT),
		"a radial shooter should fire away from its source"
	):
		return false
	source.queue_free()
	await get_tree().process_frame
	return true


func _test_targeting_uses_nearest_enemy() -> bool:
	_requests.clear()
	var source := Node2D.new()
	var shooter := TargetingShooter.new()
	var detect_area := Area2D.new()
	detect_area.name = "DetectArea"
	detect_area.collision_layer = 2
	detect_area.collision_mask = 4
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	collision.shape = CircleShape2D.new()
	detect_area.add_child(collision)
	shooter.add_child(detect_area)
	var timer := Timer.new()
	timer.name = "ShootTimer"
	shooter.add_child(timer)
	shooter.detect_area = detect_area
	shooter.detect_collision = collision
	add_child(source)
	source.add_child(shooter)
	shooter.setup(source, _spec(), 1.0)
	shooter.set_detect_radius(150.0)

	var nearest := ENEMY_SCENE.instantiate() as Enemy
	var farther := ENEMY_SCENE.instantiate() as Enemy
	nearest.position = Vector2(0.0, 40.0)
	farther.position = Vector2(100.0, 0.0)
	add_child(nearest)
	add_child(farther)
	await get_tree().physics_frame
	await get_tree().physics_frame
	shooter._on_shoot_timeout()
	if not _assert(
		_requests.size() == 1 and _requests[0].direction.is_equal_approx(Vector2.DOWN),
		"a targeting shooter should fire at the nearest enemy"
	):
		return false

	_requests.clear()
	shooter.auto_fire = false
	shooter._on_shoot_timeout()
	if not _assert(_requests.is_empty(), "manual targeting shooters should not auto-fire"):
		return false
	shooter.fire_at(farther)
	if not _assert(_requests.size() == 1, "manual targeting shooters should support fire_at"):
		return false
	source.queue_free()
	nearest.queue_free()
	farther.queue_free()
	await get_tree().process_frame
	return true


func _test_ring_evenly_distributes_shooters() -> bool:
	var source := Node2D.new()
	var ring := ShooterRing.new()
	add_child(source)
	source.add_child(ring)
	ring.setup(2, ShooterType.Type.RADIAL, 4, _spec(), 1.0, 0.0, 0.0)
	ring.set_ring_radius(70.0)
	var expected := [
		Vector2(70.0, 0.0),
		Vector2(0.0, 70.0),
		Vector2(-70.0, 0.0),
		Vector2(0.0, -70.0),
	]
	if not _assert(ring.get_shooters().size() == 4, "four copies should create four shooters"):
		return false
	for index in expected.size():
		if not _assert(
			ring.get_shooters()[index].position.is_equal_approx(expected[index]),
			"shooters should be evenly distributed around their ring"
		):
			return false
	source.queue_free()
	await get_tree().process_frame
	return true


func _test_coordinator_stably_layers_rings() -> bool:
	var coordinator := ShooterRingCoordinator.new()
	coordinator.base_radius = 70.0
	coordinator.layer_spacing = 35.0
	add_child(coordinator)
	var ring_8 := _empty_ring(8)
	var ring_2 := _empty_ring(2)
	var ring_5 := _empty_ring(5)
	coordinator.add_child(ring_8)
	coordinator.add_child(ring_2)
	coordinator.add_child(ring_5)
	coordinator.register_ring(ring_8)
	coordinator.register_ring(ring_2)
	coordinator.register_ring(ring_5)
	await get_tree().process_frame
	if not _assert(
		ring_2.ring_radius == 70.0
		and ring_5.ring_radius == 105.0
		and ring_8.ring_radius == 140.0,
		"rings should be layered by equipment id rather than registration order"
	):
		return false
	coordinator.queue_free()
	await get_tree().process_frame
	return true


func _test_rotating_ring_keeps_spacing() -> bool:
	var source := Node2D.new()
	var ring := ShooterRing.new()
	add_child(source)
	source.add_child(ring)
	ring.setup(5, ShooterType.Type.ROTATING_RADIAL, 2, _spec(), 1.0, 0.0, 2.0)
	ring.set_ring_radius(70.0)
	var initial_delta: float = (
		ring.get_shooters()[1].global_position - ring.get_shooters()[0].global_position
	).length()
	ring.advance_rotation(0.5)
	if not _assert(is_equal_approx(ring.rotation, 1.0), "rotating rings should advance by speed times delta"):
		return false
	var rotated_delta: float = (
		ring.get_shooters()[1].global_position - ring.get_shooters()[0].global_position
	).length()
	if not _assert(
		is_equal_approx(initial_delta, rotated_delta),
		"rotating a ring should preserve shooter spacing"
	):
		return false
	source.queue_free()
	await get_tree().process_frame
	return true


func _empty_ring(equipment_id: int) -> ShooterRing:
	var ring := ShooterRing.new()
	ring.equipment_id = equipment_id
	return ring


func _spec() -> ProjectileSpec:
	var result := ProjectileSpec.new()
	result.direct_damage = 10.0
	result.speed = 100.0
	result.source_faction = ProjectileSpec.Faction.PLAYER
	return result


func _on_projectile_requested(request: ProjectileSpawnRequest) -> void:
	_requests.append(request)


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("SHOOTER LAYOUT TEST FAILED: %s" % message)
	get_tree().quit(1)
	return false
