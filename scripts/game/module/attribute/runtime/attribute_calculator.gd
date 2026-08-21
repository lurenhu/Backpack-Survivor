class_name AttributeCalculator
extends RefCounted


static func calculate(base: float, flat: float, percent: float) -> float:
	return (base + flat) * (1.0 + percent)
