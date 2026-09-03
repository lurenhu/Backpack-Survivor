class_name ProjectileSpecFactory
extends RefCounted
## 将装备 Attr 配置转换为运行时子弹属性。


## 根据装备数据与发射阵营创建 ProjectileSpec；子弹类型无效时返回 null。
static func from_equipment(
	data: EquipmentData,
	source_faction: ProjectileSpec.Faction
) -> ProjectileSpec:
	if data == null:
		return null
	var bullet_type := BulletType.from_attr(data.attr)
	if bullet_type == BulletType.Type.UNKNOWN:
		DebugUtility.error(
			"ProjectileSpecFactory",
			"装备 %d 的 BULLET_TYPE 无效: %s" % [data.id, data.attr.get("BULLET_TYPE", "")]
		)
		return null

	var result := ProjectileSpec.new()
	result.bullet_type = bullet_type
	result.direct_damage = float(data.attr.get("ATK", 0.0))
	result.speed = float(data.attr.get("BULLET_SPEED", 0.0))
	result.max_hit_count = maxi(int(data.attr.get("PENETRATION_COUNT", 1)), 1)
	result.explosion_damage = float(data.attr.get("EXPLOSION_DAMAGE", 0.0))
	result.explosion_radius = float(data.attr.get("EXPLOSION_RADIUS", 0.0))
	result.shot_count = maxi(int(data.attr.get("SHOOT_NUM", 1)), 1)
	result.source_faction = source_faction
	return result
