class_name ShooterRingCoordinator
extends Node2D
## 统一管理玩家身上的发射器圆环，并按装备 ID 分配同心圆层级。

## 最内层发射器圆环的半径。
@export var base_radius: float = 70.0
## 相邻装备圆环之间增加的半径。
@export var layer_spacing: float = 35.0

## 当前参与层级布局的所有圆环。
var _rings: Array[ShooterRing] = []
## 防止同一帧重复安排延迟布局。
var _relayout_queued: bool = false


## 注册装备圆环，并在当前操作完成后重新计算所有层级半径。
func register_ring(ring: ShooterRing) -> void:
	if ring == null or _rings.has(ring):
		return
	_rings.append(ring)
	_queue_relayout()


## 注销装备圆环，并重新收紧剩余圆环的层级。
func unregister_ring(ring: ShooterRing) -> void:
	_rings.erase(ring)
	_queue_relayout()


## 返回当前已注册的发射器圆环列表。
func get_rings() -> Array[ShooterRing]:
	return _rings


## 合并同一帧内的多次布局请求，避免重复计算和修改节点状态。
func _queue_relayout() -> void:
	if _relayout_queued:
		return
	_relayout_queued = true
	call_deferred("_relayout")


## 清理失效圆环，按装备 ID 排序，并应用“基础半径 + 层索引 × 间距”。
func _relayout() -> void:
	_relayout_queued = false
	_rings = _rings.filter(func(ring: ShooterRing) -> bool: return is_instance_valid(ring))
	_rings.sort_custom(
		func(left: ShooterRing, right: ShooterRing) -> bool:
			return left.equipment_id < right.equipment_id
	)
	for index in _rings.size():
		_rings[index].set_ring_radius(base_radius + index * layer_spacing)
