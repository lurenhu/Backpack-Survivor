class_name EquipmentTipDisplayConfig
extends Resource
## 装备提示文本与装备类型样式配置。

@export var equipment_types: Array[EquipmentTipDisplayEntry] = []
@export var attributes: Array[EquipmentTipDisplayEntry] = []


func find_equipment_type(type: EquipmentEffectType.Type) -> EquipmentTipDisplayEntry:
	var key: String = String(EquipmentEffectType.Type.find_key(type))
	for entry in equipment_types:
		if entry != null and entry.key == key:
			return entry
	return null


func find_attribute(key: String, value: Variant) -> EquipmentTipDisplayEntry:
	for entry in attributes:
		if entry != null and entry.matches(key, value, true):
			return entry
	for entry in attributes:
		if entry != null and entry.matches(key):
			return entry
	return null
