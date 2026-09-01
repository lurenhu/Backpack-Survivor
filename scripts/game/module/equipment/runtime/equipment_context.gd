class_name EquipmentContext
extends RefCounted

var player: Player
var weapon_anchor: Node2D
var shooter_anchor: Node2D
var area_anchor: Node2D


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
	return self
