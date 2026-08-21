class_name EquipmentContext
extends RefCounted

var player: Player
var weapon_anchor: Node2D
var shooter_anchor: Node2D
var attribute_container: AttributeContainer


func setup(
	owner: Player,
	rotate_anchor: Node2D,
	ranged_anchor: Node2D,
	attributes: AttributeContainer = null
) -> EquipmentContext:
	player = owner
	weapon_anchor = rotate_anchor
	shooter_anchor = ranged_anchor
	attribute_container = attributes
	return self
