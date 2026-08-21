class_name EquipmentHost
extends Node

var _active_effects: Array[EquipmentEffect] = []


func initialize(equipments: Array, context: EquipmentContext) -> void:
	cleanup()

	var equipment_counts: Dictionary[int, int] = {}
	for equipment: Equipment in equipments:
		equipment_counts[equipment.id] = equipment_counts.get(equipment.id, 0) + 1

	for equipment_id in equipment_counts:
		var data: EquipmentData = GameConfig.equipment.get(equipment_id)
		if data == null:
			DebugUtility.warn("EquipmentHost", "未找到装备配置: %s" % equipment_id)
			continue

		var effect := EquipmentEffectFactory.create_effect(data.type)
		if effect == null:
			DebugUtility.warn("EquipmentHost", "未知装备效果类型: %s" % data.type)
			continue

		effect.setup(context, data, equipment_counts[equipment_id])
		effect.activate()
		_active_effects.append(effect)


func cleanup() -> void:
	for effect in _active_effects:
		effect.cleanup()
	_active_effects.clear()


func _exit_tree() -> void:
	cleanup()
