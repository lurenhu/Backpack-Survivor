class_name ExplosiveBullet
extends BulletBase
## 爆炸子弹，直接命中后对周围其他敌人追加独立范围伤害。

## 防止一次命中安排多次爆炸查询。
var _explosion_pending: bool = false


## 先结算直接命中伤害，再延迟执行范围查询以避开物理刷新阶段。
func _on_valid_target_hit(body: Node2D) -> void:
	if _explosion_pending:
		return
	_explosion_pending = true
	_deal_damage(body, spec.direct_damage)
	set_physics_process(false)
	call_deferred("_apply_explosion", global_position, body.get_instance_id())


## 查询爆炸圆内的敌对目标；排除直接命中目标并对其余目标造成范围伤害。
func _apply_explosion(explosion_position: Vector2, direct_target_id: int) -> void:
	if spec == null:
		_finish()
		return
	if spec.explosion_damage <= 0.0 or spec.explosion_radius <= 0.0:
		_finish()
		return

	var shape := CircleShape2D.new()
	shape.radius = spec.explosion_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, explosion_position)
	query.collision_mask = 4 if spec.source_faction == ProjectileSpec.Faction.PLAYER else 2
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var damaged_targets: Dictionary[int, bool] = {}
	for result: Dictionary in get_world_2d().direct_space_state.intersect_shape(query):
		var body := result.get("collider") as Node2D
		if body == null or not _is_valid_target(body):
			continue
		var target_id := body.get_instance_id()
		if target_id == direct_target_id or damaged_targets.has(target_id):
			continue
		damaged_targets[target_id] = true
		_deal_damage(body, spec.explosion_damage)
	_finish()
