class_name EquipmentHost
extends Node

var _active_effects: Array[EquipmentEffect] = []


func initialize(equipments: Array, context: EquipmentContext) -> void:
	cleanup()

	var equipment_groups: Dictionary[int, Array] = {}
	for equipment: Equipment in equipments:
		if not equipment_groups.has(equipment.id):
			var group: Array[Equipment] = []
			equipment_groups[equipment.id] = group
		var group: Array[Equipment] = equipment_groups[equipment.id]
		group.append(equipment)

	for equipment_id in equipment_groups:
		var data: EquipmentData = GameConfig.equipment.get(equipment_id)
		if data == null:
			DebugUtility.warn("EquipmentHost", "未找到装备配置: %s" % equipment_id)
			continue
		if data.type == EquipmentEffectType.Type.PASSIVE_ATTRIBUTE:
			continue

		var effect := EquipmentEffectFactory.create_effect(data.type)
		if effect == null:
			DebugUtility.warn("EquipmentHost", "未知装备效果类型: %s" % data.type)
			continue

		var sources: Array[Equipment] = equipment_groups[equipment_id]
		effect.setup(context, data, sources)
		_active_effects.append(effect)
		effect.activate()


func cleanup() -> void:
	for effect in _active_effects:
		effect.cleanup()
	_active_effects.clear()


func _exit_tree() -> void:
	cleanup()
