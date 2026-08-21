class_name ShooterEffect
extends EquipmentEffect

const SHOOTER_SCENE: PackedScene = preload("res://scene/battle/entities/shooter.tscn")


func activate() -> void:
	if context == null or context.shooter_anchor == null:
		DebugUtility.error("ShooterEffect", "缺少 ShooterAnchor")
		return
	var equipment_count := get_count()
	if equipment_data == null or equipment_count <= 0:
		return

	var damage := float(equipment_data.attr.get(AttrType.get_key(AttrType.Type.ATK), 0.0))
	var shoot_interval := float(equipment_data.attr.get(AttrType.get_key(AttrType.Type.SHOOT_INTERVAL), 0.0))
	var bullet_speed := float(equipment_data.attr.get(AttrType.get_key(AttrType.Type.BULLET_SPEED), 0.0))
	var shoot_radius := float(equipment_data.attr.get(AttrType.get_key(AttrType.Type.SHOOT_RADIUS), 0.0))

	var shooter := SHOOTER_SCENE.instantiate() as Shooter
	if shooter == null:
		DebugUtility.error("ShooterEffect", "无法创建发射装备场景")
		return
	context.shooter_anchor.add_child(shooter)
	shooter.setup(shoot_interval, bullet_speed, damage, shoot_radius, equipment_count, context.player, context.attribute_container)
	shooter.pos_shooter(-PI / 2.0)
	_track_entity(shooter)
