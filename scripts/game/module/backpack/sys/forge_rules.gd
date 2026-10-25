class_name ForgeRules
extends RefCounted

## 排序比较保留材料数量；配方预览与提交使用同一规则。
static func find_recipe(material_ids: Array[int], recipes: Dictionary) -> EquipmentForgeData:
	if material_ids.is_empty():
		return null
	var ids := PackedInt32Array(material_ids)
	ids.sort()
	for recipe: EquipmentForgeData in recipes.values():
		var expected := recipe.material_ids.duplicate()
		expected.sort()
		if expected == ids:
			return recipe
	return null
