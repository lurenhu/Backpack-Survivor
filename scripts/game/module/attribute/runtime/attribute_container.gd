class_name AttributeContainer
extends RefCounted

signal attribute_changed(type: AttrType.Type)

var _modifiers: Array[AttributeModifier] = []


func add_modifier(modifier: AttributeModifier) -> void:
	_modifiers.append(modifier)
	attribute_changed.emit(modifier.attribute)


func remove_by_source(source: Equipment) -> void:
	var affected_types: Dictionary = {}
	for modifier in _modifiers:
		if modifier.source_equipment == source:
			affected_types[modifier.attribute] = true
	_modifiers = _modifiers.filter(func(modifier: AttributeModifier) -> bool: return modifier.source_equipment != source)
	for type in affected_types:
		attribute_changed.emit(type)


func get_total(type: AttrType.Type) -> float:
	var total := 0.0
	for modifier in _modifiers:
		if modifier.attribute == type:
			total += modifier.value
	return total


func calculate(base: float, flat_type: AttrType.Type, percent_type: AttrType.Type) -> float:
	return AttributeCalculator.calculate(base, get_total(flat_type), get_total(percent_type))


func clear() -> void:
	var affected_types: Dictionary = {}
	for modifier in _modifiers:
		affected_types[modifier.attribute] = true
	_modifiers.clear()
	for type in affected_types:
		attribute_changed.emit(type)
