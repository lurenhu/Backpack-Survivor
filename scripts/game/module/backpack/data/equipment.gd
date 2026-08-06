class_name Equipment
extends RefCounted
## 装备数据：持有配置ID、形状和旋转状态

enum EQUIPMENT_STATE {
	SHOP = 0,
	BACKPACK,
	STAGE,
}

enum EQUIPMENT_TYPE {
	ROTATE = 0,
	SHOOTER,
}

var config_id: int = 0
var shape: Array[Array] = []
var rotate_times: int = 0
var type: EQUIPMENT_TYPE = EQUIPMENT_TYPE.ROTATE

## 在背包或者暂存区的网格坐标
var grid_pos: Vector2i = Vector2i.ZERO
## 当前装备位于哪个状态
var state: EQUIPMENT_STATE = EQUIPMENT_STATE.SHOP

## 初始化装备数据：加载配置并记录形状
func _init(p_config_id: int) -> void:
	config_id = p_config_id
	var config: EquipmentData = GameConfig.equipment[config_id]
	if config == null:
		return
	shape = config.shape.duplicate(true)
	type = config.type


## 顺时针旋转90度并更新形状
func rotate_clockwise() -> Array[Array]:
	rotate_times = (rotate_times + 1) % 4
	shape = _rotate_shape_90(shape)
	return shape

## 判断两个装备的所有内部变量是否完全相等
func is_equal(other: Equipment) -> bool:
	if not other:
		return false
	if config_id != other.config_id:
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
	var new_equip: Equipment = Equipment.new(config_id)
	new_equip.rotate_times = rotate_times
	new_equip.grid_pos = grid_pos
	new_equip.state = state
	new_equip.shape = shape.duplicate(true)
	return new_equip

## 将形状矩阵顺时针旋转90度
static func _rotate_shape_90(s: Array[Array]) -> Array[Array]:
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
