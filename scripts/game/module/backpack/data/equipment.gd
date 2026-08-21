class_name Equipment
extends RefCounted
## 装备数据：持有配置ID、形状和旋转状态

var id: int = 0
var name: String
var rarity: int
var price: int
var source: String
var shape: Array[Array] = []

## 当前装备在网格中的旋转次数
var rotate_times: int = 0
## 在背包或者暂存区的网格坐标
var grid_pos: Vector2i = Vector2i.ZERO
## 预览装备数据
var preview_equipment: Equipment = null
## 当前装备位于哪个状态
var state: BackpackManager.GridType = BackpackManager.GridType.NONE

## 初始化装备数据：加载配置并记录形状
func _init(equipment_id: int) -> void:
	var config: EquipmentData = GameConfig.equipment[equipment_id]
	if config == null:
		return
	
	id = equipment_id
	name = config.name
	rarity = config.rarity
	price = config.price
	source = config.source
	shape = config.shape.duplicate(true)

	preview_equipment = null
	state = BackpackManager.GridType.NONE


## 顺时针旋转90度并更新形状
func rotate_clockwise() -> Array[Array]:
	rotate_times = (rotate_times + 1) % 4
	shape = _rotate_shape_90(shape)
	return shape

## 判断两个装备的所有内部变量是否完全相等
func is_equal(other: Equipment) -> bool:
	if not other:
		return false
	if id != other.id:
		return false
	if rotate_times != other.rotate_times:
		return false
	if grid_pos != other.grid_pos:
		return false
	if state != other.state:
		return false
	return true


## 深拷贝当前装备，包括形状矩阵
func copy() -> Equipment:
	var new_equip: Equipment = Equipment.new(id)
	new_equip.rotate_times = rotate_times
	new_equip.grid_pos = grid_pos
	new_equip.state = state
	new_equip.shape = shape.duplicate(true)
	new_equip.preview_equipment = preview_equipment
	return new_equip


## 完全复制传入装备数值
func copy_equipment(equipment: Equipment):
	id = equipment.id
	name = equipment.name
	rarity = equipment.rarity
	price = equipment.price
	source = equipment.source
	shape = equipment.shape.duplicate(true)
	rotate_times = equipment.rotate_times
	grid_pos = equipment.grid_pos
	state = equipment.state
	preview_equipment = equipment.preview_equipment


## 将形状矩阵顺时针旋转90度
func _rotate_shape_90(s: Array[Array]) -> Array[Array]:
	if s.is_empty():
		return []
	var old_h: int = s.size()
	var old_w: int = s[0].size()
	var result: Array[Array] = []
	for y in old_w:
		var row: Array = []
		for x in old_h:
			row.append(s[old_h - 1 - x][y])
		result.append(row)
	return result
