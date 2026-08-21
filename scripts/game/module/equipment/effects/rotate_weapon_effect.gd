class_name RotateWeaponEffect
extends EquipmentEffect

const ROTATE_WEAPON_SCENE: PackedScene = preload("res://scene/battle/entities/rotate_weapon.tscn")


func activate() -> void:
	if context == null or context.weapon_anchor == null:
		DebugUtility.error("RotateWeaponEffect", "缺少 WeaponAnchor")
		return
	var equipment_count := get_count()
	if equipment_data == null or equipment_count <= 0:
		return

	var damage := float(equipment_data.attr.get(AttrType.get_key(AttrType.Type.ATK), 0.0))
	var rotate_radius := float(equipment_data.attr.get(AttrType.get_key(AttrType.Type.ROTATE_RADIUS), 0.0))
	var rotate_speed := float(equipment_data.attr.get(AttrType.get_key(AttrType.Type.ROTATE_SPEED), 0.0))
	var texture := load(equipment_data.source) as Texture2D
	if texture == null:
		DebugUtility.error("RotateWeaponEffect", "无法加载装备贴图: %s" % equipment_data.source)
		return

	for index in equipment_count:
		var weapon := ROTATE_WEAPON_SCENE.instantiate() as RotateWeapon
		if weapon == null:
			DebugUtility.error("RotateWeaponEffect", "无法创建旋转武器场景")
			continue
		context.weapon_anchor.add_child(weapon)
		weapon.setup(damage, rotate_radius, rotate_speed, equipment_data.shape, texture)
		weapon._angle = index * TAU / equipment_count
		_track_entity(weapon)
