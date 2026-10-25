class_name BattleContext
extends RefCounted
## 单场战斗拥有的场景引用；退出时主动释放，不保存 UI。

var scene_root: Node
var enemy_container: Node2D
var pickup_container: Node2D
var spawn_points: Array[Marker2D] = []


func is_valid() -> bool:
	if not is_instance_valid(scene_root) or not scene_root.is_inside_tree() or scene_root.is_queued_for_deletion():
		return false
	for container in [enemy_container, pickup_container]:
		if not is_instance_valid(container) or not owns(container):
			return false
	if spawn_points.is_empty():
		return false
	for point in spawn_points:
		if not is_instance_valid(point) or not owns(point):
			return false
	return true


func owns(node: Node) -> bool:
	return is_instance_valid(scene_root) and is_instance_valid(node) \
		and scene_root.is_inside_tree() and not scene_root.is_queued_for_deletion() \
		and node.is_inside_tree() and not node.is_queued_for_deletion() \
		and scene_root.is_ancestor_of(node)


func clear() -> void:
	scene_root = null
	enemy_container = null
	pickup_container = null
	spawn_points.clear()
