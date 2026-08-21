class_name AttributeModifier
extends RefCounted

var source_equipment: Equipment
var attribute: AttrType.Type
var value: float


func _init(source: Equipment, type: AttrType.Type, amount: float) -> void:
	source_equipment = source
	attribute = type
	value = amount
