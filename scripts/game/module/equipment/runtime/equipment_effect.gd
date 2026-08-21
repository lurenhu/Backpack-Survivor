class_name EquipmentEffect
extends RefCounted

var context: EquipmentContext
var equipment_data: EquipmentData
var count: int = 0

var _created_entities: Array[Node] = []


func setup(new_context: EquipmentContext, data: EquipmentData, equipment_count: int) -> void:
	context = new_context
	equipment_data = data
	count = equipment_count


func activate() -> void:
	pass


func cleanup() -> void:
	for entity in _created_entities:
		if is_instance_valid(entity):
			entity.queue_free()
	_created_entities.clear()


func _track_entity(entity: Node) -> void:
	_created_entities.append(entity)
