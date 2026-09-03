class_name ShooterType
extends RefCounted
## 发射器类型定义与配置解析工具。

## UNKNOWN 用于拒绝非法显式配置；其余类型分别表示固定径向、旋转径向和锁敌发射。
enum Type {
	UNKNOWN = -1,
	RADIAL,
	ROTATING_RADIAL,
	TARGETING,
}


## 将配置字符串转换为发射器类型；无法识别时返回 UNKNOWN。
static func from_string(value: String) -> Type:
	match value.strip_edges().to_upper():
		"RADIAL":
			return Type.RADIAL
		"ROTATING_RADIAL":
			return Type.ROTATING_RADIAL
		"TARGETING":
			return Type.TARGETING
		_:
			return Type.UNKNOWN


## 从装备 Attr 字典读取 SHOOTER_TYPE；旧配置缺少该字段时兼容为 TARGETING。
static func from_attr(attr: Dictionary) -> Type:
	if not attr.has("SHOOTER_TYPE"):
		return Type.TARGETING
	return from_string(str(attr["SHOOTER_TYPE"]))
