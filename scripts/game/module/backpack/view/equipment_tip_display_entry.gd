class_name EquipmentTipDisplayEntry
extends Resource
## 装备提示中的一条可编辑显示规则。

@export var key: String = ""
## 留空表示匹配该属性的任意值；填写后优先进行精确匹配。
@export var value: String = ""
## 支持使用 {value} 插入原始属性值。
@export var text_template: String = "{value}"
## 仅装备类型标签使用；属性标签沿用其场景中的样式。
@export var label_settings: LabelSettings


func matches(target_key: String, target_value: Variant = null, exact_value: bool = false) -> bool:
	if key != target_key:
		return false
	if not exact_value:
		return value.is_empty()
	return not value.is_empty() and value == str(target_value)


func format(target_value: Variant) -> String:
	return text_template.replace("{value}", str(target_value))
