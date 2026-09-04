class_name AttrLabel
extends Label
## 将装备属性键值转换为配置文本，并保留场景中设置的 LabelSettings。


func setup(key: String, value: Variant, config: EquipmentTipDisplayConfig) -> void:
	var entry := config.find_attribute(key, value) if config != null else null
	text = entry.format(value) if entry != null else "%s: %s" % [key, value]
