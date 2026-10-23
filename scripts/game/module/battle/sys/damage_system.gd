class_name DamageSystem
extends RefCounted
## 同步处理伤害，不依赖 HUD 或全局管理器。
## 受伤目标须为 Node2D，提供数值 current_hp 和 take_damage(float) -> bool。


func apply_damage(request: DamageRequest) -> DamageResult:
	var result := DamageResult.new()
	if request == null:
		return result
	result.source = request.source if is_instance_valid(request.source) else null
	if not is_instance_valid(request.target):
		return result
	result.target = request.target
	var target := request.target as Node2D
	if target == null or target.is_queued_for_deletion():
		return result
	if not is_finite(request.amount) or request.amount <= 0.0:
		return result
	if not target.has_method("take_damage"):
		return result
	var health: Variant = target.get("current_hp")
	if not (health is float or health is int):
		return result
	var previous_hp: float = float(health)
	if not is_finite(previous_hp) or previous_hp <= 0.0:
		return result

	result.world_position = target.global_position
	result.remaining_hp = previous_hp
	if not target.take_damage(request.amount):
		return result

	# 死亡回调可能释放目标；位置已在扣血前保存。
	result.remaining_hp = maxf(float(target.get("current_hp")), 0.0) if is_instance_valid(target) else 0.0
	result.actual_damage = maxf(previous_hp - result.remaining_hp, 0.0)
	result.applied = result.actual_damage > 0.0
	result.killed = result.applied and result.remaining_hp <= 0.0
	return result
