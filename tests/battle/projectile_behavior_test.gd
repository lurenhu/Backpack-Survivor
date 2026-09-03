extends Node

const ENEMY_SCENE: PackedScene = preload("res://scene/battle/entities/enemy_slime.tscn")

var _damage_by_target: Dictionary[int, Array] = {}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	CombatManager.damage_dealt.connect(_on_damage_dealt)
	if not await _test_normal_bullet_hits_once():
		return
	if not await _test_spawner_defers_normal_bullet():
		return
	if not await _test_piercing_bullet_counts_unique_targets():
		return
	if not await _test_explosion_excludes_direct_target():
		return
	CombatManager.damage_dealt.disconnect(_on_damage_dealt)
	get_tree().quit(0)


func _test_normal_bullet_hits_once() -> bool:
	_damage_by_target.clear()
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	add_child(enemy)
	var bullet := NormalBullet.new()
	add_child(bullet)
	bullet.setup(_request(BulletType.Type.NORMAL))
	bullet._on_body_entered(enemy)
	bullet._on_body_entered(enemy)
	var target_damage: Array = _damage_by_target.get(enemy.get_instance_id(), [])
	if not _assert(target_damage == [10.0], "normal bullets should damage the first target once"):
		return false
	await get_tree().process_frame
	enemy.queue_free()
	return true


func _test_spawner_defers_normal_bullet() -> bool:
	var container := Node2D.new()
	add_child(container)
	var spawner := BulletSpawner.new()
	spawner.bullet_container = container
	add_child(spawner)
	spawner.spawn(_request(BulletType.Type.NORMAL))
	if not _assert(container.get_child_count() == 0, "bullet spawning should be deferred"):
		return false
	await get_tree().process_frame
	if not _assert(
		container.get_child_count() == 1 and container.get_child(0) is NormalBullet,
		"a NORMAL request should create a NormalBullet"
	):
		return false
	container.queue_free()
	spawner.queue_free()
	await get_tree().process_frame
	return true


func _test_piercing_bullet_counts_unique_targets() -> bool:
	_damage_by_target.clear()
	var enemy_a := ENEMY_SCENE.instantiate() as Enemy
	var enemy_b := ENEMY_SCENE.instantiate() as Enemy
	add_child(enemy_a)
	add_child(enemy_b)
	var request := _request(BulletType.Type.PIERCING)
	request.spec.max_hit_count = 2
	var bullet := PiercingBullet.new()
	add_child(bullet)
	bullet.setup(request)
	bullet._on_body_entered(enemy_a)
	bullet._on_body_entered(enemy_a)
	bullet._on_body_entered(enemy_b)
	if not _assert(
		_damage_by_target.get(enemy_a.get_instance_id(), []) == [10.0]
		and _damage_by_target.get(enemy_b.get_instance_id(), []) == [10.0],
		"piercing bullets should count two different targets"
	):
		return false
	await get_tree().process_frame
	enemy_a.queue_free()
	enemy_b.queue_free()
	return true


func _test_explosion_excludes_direct_target() -> bool:
	_damage_by_target.clear()
	var direct := ENEMY_SCENE.instantiate() as Enemy
	var nearby := ENEMY_SCENE.instantiate() as Enemy
	var far_away := ENEMY_SCENE.instantiate() as Enemy
	direct.position = Vector2.ZERO
	nearby.position = Vector2(40.0, 0.0)
	far_away.position = Vector2(300.0, 0.0)
	add_child(direct)
	add_child(nearby)
	add_child(far_away)
	await get_tree().physics_frame

	var request := _request(BulletType.Type.EXPLOSIVE)
	request.spec.explosion_damage = 20.0
	request.spec.explosion_radius = 100.0
	var bullet := ExplosiveBullet.new()
	add_child(bullet)
	bullet.setup(request)
	bullet._on_body_entered(direct)
	await get_tree().process_frame
	if not _assert(
		_damage_by_target.get(direct.get_instance_id(), []) == [10.0]
		and _damage_by_target.get(nearby.get_instance_id(), []) == [20.0]
		and not _damage_by_target.has(far_away.get_instance_id()),
		"explosions should damage nearby enemies but exclude the direct target"
	):
		return false
	direct.queue_free()
	nearby.queue_free()
	far_away.queue_free()
	await get_tree().process_frame
	return true


func _request(type: BulletType.Type) -> ProjectileSpawnRequest:
	var spec := ProjectileSpec.new()
	spec.bullet_type = type
	spec.direct_damage = 10.0
	spec.speed = 100.0
	spec.source_faction = ProjectileSpec.Faction.PLAYER
	return ProjectileSpawnRequest.create(Vector2.ZERO, Vector2.RIGHT, spec)


func _on_damage_dealt(target: Node, amount: float) -> void:
	var target_id := target.get_instance_id()
	if not _damage_by_target.has(target_id):
		_damage_by_target[target_id] = []
	_damage_by_target[target_id].append(amount)


func _assert(condition: bool, message: String) -> bool:
	if condition:
		return true
	push_error("PROJECTILE BEHAVIOR TEST FAILED: %s" % message)
	get_tree().quit(1)
	return false
