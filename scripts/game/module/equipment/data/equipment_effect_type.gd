class_name EquipmentEffectType
extends RefCounted

enum Type {
	UNKNOWN = -1,
	ROTATE,
	SHOOTER,
}


static func from_string(value: String) -> Type:
	match value:
		"ROTATE", "JEWELRY":
			return Type.ROTATE
		"SHOOTER":
			return Type.SHOOTER
		_:
			return Type.UNKNOWN
