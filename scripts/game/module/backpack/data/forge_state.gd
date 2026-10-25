class_name ForgeState
extends RefCounted

## 实例编号 -> {position: Vector2i, rotation: int}；原装备仍留在原区域。
var selections: Dictionary[int, Dictionary] = {}
var pending_reward: Equipment
