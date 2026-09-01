class_name AreaWeaponEffect
extends EquipmentEffect

const AREA_WEAPON_SCENE: PackedScene = preload("res://scene/battle/entities/area_weapon.tscn")


func activate() -> void:
	if context == null or context.area_anchor == null:
		DebugUtility.error("AreaWeaponEffect", "缺少 AreaAnchor")
		return
	var equipment_count := get_count()
	if equipment_data == null or equipment_count <= 0:
		return

	var damage := float(equipment_data.attr.get(AttrType.get_key(AttrType.Type.ATK), 0.0))
	var area_radius := float(equipment_data.attr.get(AttrType.get_key(AttrType.Type.AREA_RADIUS), 0.0))
	var area_interval := float(equipment_data.attr.get(AttrType.get_key(AttrType.Type.AREA_INTERVAL), 0.0))
	for _index in equipment_count:
		var weapon := AREA_WEAPON_SCENE.instantiate() as AreaWeapon
		if weapon == null:
			DebugUtility.error("AreaWeaponEffect", "无法创建范围武器场景")
			continue
		context.area_anchor.add_child(weapon)
		weapon.setup(damage, area_radius, area_interval)
		_track_entity(weapon)
