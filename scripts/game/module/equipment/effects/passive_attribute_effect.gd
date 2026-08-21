class_name PassiveAttributeEffect
extends EquipmentEffect


func activate() -> void:
	if context == null or context.attribute_container == null or equipment_data == null:
		return
	for source in source_equipments:
		for key in equipment_data.attr:
			var type := AttrType.get_type(String(key))
			if int(type) == -1:
				DebugUtility.warn("PassiveAttributeEffect", "未知属性类型: %s" % key)
				continue
			context.attribute_container.add_modifier(
				AttributeModifier.new(source, type, float(equipment_data.attr[key]))
			)


func cleanup() -> void:
	if context != null and context.attribute_container != null:
		for source in source_equipments:
			context.attribute_container.remove_by_source(source)
	super.cleanup()
