class_name EquipmentTypeLabel
extends Label
## 将装备效果类型转换为配置的显示文本与样式。


func setup(type: EquipmentEffectType.Type, config: EquipmentTipDisplayConfig) -> void:
	var entry := config.find_equipment_type(type) if config != null else null
	if entry == null:
		text = String(EquipmentEffectType.Type.find_key(type))
		return
	text = entry.text_template
	if entry.label_settings != null:
		label_settings = entry.label_settings
