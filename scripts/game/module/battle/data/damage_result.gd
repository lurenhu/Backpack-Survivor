class_name DamageResult
extends RefCounted
## 已完成的伤害结果。节点引用可能随后失效，显示层应使用数值和位置快照。

var source: Node = null
var target: Node = null
var applied: bool = false
var actual_damage: float = 0.0
var remaining_hp: float = 0.0
var world_position: Vector2 = Vector2.ZERO
var killed: bool = false
