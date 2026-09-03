class_name ShooterEffect
extends EquipmentEffect
## 发射器装备效果：将背包中的同类装备映射为一个发射器圆环。

## 当前装备效果创建并持有的圆环实例。
var _ring: ShooterRing = null


## 解析装备配置、创建发射器圆环，并注册属性变化监听。
func activate() -> void:
	if context == null or context.shooter_ring_coordinator == null:
		DebugUtility.error("ShooterEffect", "缺少 ShooterRingCoordinator")
		return
	if equipment_data == null or get_count() <= 0:
		return

	var type := ShooterType.from_attr(equipment_data.attr)
	if type == ShooterType.Type.UNKNOWN:
		DebugUtility.error(
			"ShooterEffect",
			"装备 %d 的 SHOOTER_TYPE 无效: %s" % [
				equipment_data.id,
				equipment_data.attr.get("SHOOTER_TYPE", ""),
			]
		)
		return

	var values := _calculate_values()
	if values.is_empty():
		return
	_ring = ShooterRing.new()
	_ring.name = "ShooterRing_%d" % equipment_data.id
	_ring.source = context.player
	context.shooter_ring_coordinator.add_child(_ring)
	_ring.setup(
		equipment_data.id,
		type,
		get_count(),
		values.spec,
		values.fire_interval,
		values.detect_radius,
		values.rotate_speed
	)
	context.shooter_ring_coordinator.register_ring(_ring)
	_track_entity(_ring)
	if not BackpackManager.equip_changed.is_connected(_refresh_attributes):
		BackpackManager.equip_changed.connect(_refresh_attributes)


## 断开属性监听、注销圆环，并交给基类释放已跟踪实体。
func cleanup() -> void:
	if BackpackManager.equip_changed.is_connected(_refresh_attributes):
		BackpackManager.equip_changed.disconnect(_refresh_attributes)
	if context != null and context.shooter_ring_coordinator != null and _ring != null:
		context.shooter_ring_coordinator.unregister_ring(_ring)
	_ring = null
	super()


## 背包装备属性变化时，重新计算并刷新现有发射器参数。
func _refresh_attributes() -> void:
	if _ring == null or not is_instance_valid(_ring):
		return
	var values := _calculate_values()
	if values.is_empty():
		return
	_ring.refresh(
		values.spec,
		values.fire_interval,
		values.detect_radius,
		values.rotate_speed
	)


## 合并装备基础 Attr 和背包全局加成，返回圆环运行时所需参数。
func _calculate_values() -> Dictionary:
	var spec := ProjectileSpecFactory.from_equipment(
		equipment_data,
		ProjectileSpec.Faction.PLAYER
	)
	if spec == null:
		return {}
	spec.direct_damage = (spec.direct_damage + _equipment_attr(AttrType.Type.ATK)) \
		* (1.0 + _equipment_attr(AttrType.Type.ATK_GAIN))
	spec.speed = (spec.speed + _equipment_attr(AttrType.Type.BULLET_SPEED_INC)) \
		* (1.0 + _equipment_attr(AttrType.Type.BULLET_SPEED_GAIN))
	var interval := float(equipment_data.attr.get("SHOOT_INTERVAL", 0.0)) \
		* (1.0 - _equipment_attr(AttrType.Type.SHOOT_INTERVAL_GAIN))
	var radius := float(equipment_data.attr.get("SHOOT_RADIUS", 0.0)) \
		* (1.0 + _equipment_attr(AttrType.Type.SHOOT_RADIUS_GAIN))
	var rotation := float(equipment_data.attr.get("ROTATE_SPEED", 0.0)) \
		* (1.0 + _equipment_attr(AttrType.Type.ROTATE_SPEED_GAIN))
	return {
		"spec": spec,
		"fire_interval": maxf(interval, 0.0),
		"detect_radius": maxf(radius, 0.0),
		"rotate_speed": rotation,
	}


## 安全读取背包汇总后的指定装备属性；不存在时返回 0。
func _equipment_attr(type: AttrType.Type) -> float:
	return (
		BackpackManager.equipment_attrs.get_value(type)
		if BackpackManager.equipment_attrs.has(type)
		else 0.0
	)
