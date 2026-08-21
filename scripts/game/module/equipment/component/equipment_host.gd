class_name EquipmentHost
extends Node

var attribute_container: AttributeContainer:
	get:
		return _attribute_container

var _active_effects: Array[EquipmentEffect] = []
var _attribute_container := AttributeContainer.new()


func initialize(equipments: Array, context: EquipmentContext) -> void:
	cleanup()
	context.attribute_container = _attribute_container

	var equipment_groups: Dictionary[int, Array] = {}
	for equipment: Equipment in equipments:
		if not equipment_groups.has(equipment.id):
			var group: Array[Equipment] = []
			equipment_groups[equipment.id] = group
		var group: Array[Equipment] = equipment_groups[equipment.id]
		group.append(equipment)

	var passive_effects: Array[EquipmentEffect] = []
	var entity_effects: Array[EquipmentEffect] = []
	for equipment_id in equipment_groups:
		var data: EquipmentData = GameConfig.equipment.get(equipment_id)
		if data == null:
			DebugUtility.warn("EquipmentHost", "未找到装备配置: %s" % equipment_id)
			continue

		var effect := EquipmentEffectFactory.create_effect(data.type)
		if effect == null:
			DebugUtility.warn("EquipmentHost", "未知装备效果类型: %s" % data.type)
			continue

		var sources: Array[Equipment] = equipment_groups[equipment_id]
		effect.setup(context, data, sources)
		_active_effects.append(effect)
		if data.type == EquipmentEffectType.Type.PASSIVE_ATTRIBUTE:
			passive_effects.append(effect)
		else:
			entity_effects.append(effect)

	for effect in passive_effects:
		effect.activate()
	for effect in entity_effects:
		effect.activate()


func cleanup() -> void:
	for effect in _active_effects:
		effect.cleanup()
	_active_effects.clear()
	_attribute_container.clear()


func _exit_tree() -> void:
	cleanup()
