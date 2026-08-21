class_name EquipmentEffectType
extends RefCounted

enum Type {
	UNKNOWN = -1,
	ROTATE,
	SHOOTER,
	PASSIVE_ATTRIBUTE,
}


static func from_string(value: String) -> Type:
	match value:
		"ROTATE":
			return Type.ROTATE
		"SHOOTER":
			return Type.SHOOTER
		"JEWELRY":
			return Type.PASSIVE_ATTRIBUTE
		_:
			return Type.UNKNOWN
