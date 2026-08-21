class_name EquipmentEffect
extends RefCounted

var context: EquipmentContext
var equipment_data: EquipmentData
var source_equipments: Array[Equipment] = []

var _created_entities: Array[Node] = []


func setup(new_context: EquipmentContext, data: EquipmentData, sources: Array[Equipment]) -> void:
	context = new_context
	equipment_data = data
	source_equipments = sources


func get_count() -> int:
	return source_equipments.size()


func activate() -> void:
	pass


func cleanup() -> void:
	for entity in _created_entities:
		if is_instance_valid(entity):
			entity.queue_free()
	_created_entities.clear()


func _track_entity(entity: Node) -> void:
	_created_entities.append(entity)
