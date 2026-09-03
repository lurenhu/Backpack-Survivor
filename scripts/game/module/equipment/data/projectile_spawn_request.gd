class_name ProjectileSpawnRequest
extends RefCounted
## 发射器传递给战斗场景的不可共享子弹生成参数。

## 子弹生成时的世界坐标。
var global_position: Vector2 = Vector2.ZERO
## 已归一化的飞行方向。
var direction: Vector2 = Vector2.ZERO
## 本次发射使用的独立属性快照。
var spec: ProjectileSpec = null


## 创建生成请求，并复制配置以隔离后续属性变化。
static func create(
	spawn_position: Vector2,
	shoot_direction: Vector2,
	projectile_spec: ProjectileSpec
) -> ProjectileSpawnRequest:
	var result := ProjectileSpawnRequest.new()
	result.global_position = spawn_position
	result.direction = shoot_direction.normalized()
	result.spec = projectile_spec.snapshot() if projectile_spec != null else null
	return result
