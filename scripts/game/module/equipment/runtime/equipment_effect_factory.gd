class_name EquipmentEffectFactory
extends RefCounted


static func create_effect(type: EquipmentEffectType.Type) -> EquipmentEffect:
	match type:
		EquipmentEffectType.Type.ROTATE:
			return RotateWeaponEffect.new()
		EquipmentEffectType.Type.SHOOTER:
			return ShooterEffect.new()
		EquipmentEffectType.Type.PASSIVE_ATTRIBUTE:
			return PassiveAttributeEffect.new()
		_:
			return null
