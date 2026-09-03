class_name EquipmentContext
extends RefCounted
## 装备效果共享的运行时节点引用，避免效果脚本直接依赖固定场景路径。

## 当前装备效果所属的玩家。
var player: Player
## 旋转近战武器的挂载节点。
var weapon_anchor: Node2D
## 发射器装备的挂载节点。
var shooter_anchor: Node2D
## 范围效果装备的挂载节点。
var area_anchor: Node2D
## 负责发射器同心圆层级布局的协调器。
var shooter_ring_coordinator: ShooterRingCoordinator


## 保存玩家和各类装备锚点，并从发射器锚点解析圆环协调器。
func setup(
	owner: Player,
	rotate_anchor: Node2D,
	ranged_anchor: Node2D,
	range_anchor: Node2D = null
) -> EquipmentContext:
	player = owner
	weapon_anchor = rotate_anchor
	shooter_anchor = ranged_anchor
	area_anchor = range_anchor
	shooter_ring_coordinator = (
		shooter_anchor.get_node_or_null("ShooterRingCoordinator") as ShooterRingCoordinator
		if shooter_anchor != null
		else null
	)
	return self
