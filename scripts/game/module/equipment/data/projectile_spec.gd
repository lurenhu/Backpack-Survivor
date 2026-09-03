class_name ProjectileSpec
extends RefCounted
## 一次射击使用的子弹属性快照，避免装备属性变化影响已经发射的子弹。

## 标记子弹所属阵营，用于筛选合法伤害目标和友军。
enum Faction {
	PLAYER,
	ENEMY,
}

## 子弹行为类型。
var bullet_type: BulletType.Type = BulletType.Type.NORMAL
## 命中目标时造成的直接伤害。
var direct_damage: float = 0.0
## 子弹每秒移动速度。
var speed: float = 0.0
## 穿透子弹最多能够命中的不同目标总数。
var max_hit_count: int = 1
## 爆炸对子目标造成的范围伤害。
var explosion_damage: float = 0.0
## 爆炸范围半径。
var explosion_radius: float = 0.0
## 每次射击同时生成的子弹数量。
var shot_count: int = 1
## 发射者阵营。
var source_faction: Faction = Faction.PLAYER
## 子弹未命中任何物体时的最长存活时间。
var max_lifetime: float = 10.0


## 创建当前配置的独立副本，供发射请求和子弹安全持有。
func snapshot() -> ProjectileSpec:
	var result := ProjectileSpec.new()
	result.bullet_type = bullet_type
	result.direct_damage = direct_damage
	result.speed = speed
	result.max_hit_count = max_hit_count
	result.explosion_damage = explosion_damage
	result.explosion_radius = explosion_radius
	result.shot_count = shot_count
	result.source_faction = source_faction
	result.max_lifetime = max_lifetime
	return result
