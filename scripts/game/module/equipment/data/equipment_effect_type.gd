class_name EquipmentEffectType
extends RefCounted

enum Type {
	UNKNOWN = -1,
	ROTATE,
	SHOOTER,
	AREA,
	PASSIVE_ATTRIBUTE,
}


static func from_string(value: String) -> Type:
	match value:
		"ROTATE":
			return Type.ROTATE
		"SHOOTER":
			return Type.SHOOTER
		"AREA":
			return Type.AREA
		"JEWELRY":
			return Type.PASSIVE_ATTRIBUTE
		_:
			return Type.UNKNOWN
