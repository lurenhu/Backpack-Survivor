class_name BulletType
extends RefCounted
## 子弹类型定义与配置解析工具。

## UNKNOWN 用于拒绝非法显式配置；其余类型分别表示普通、穿透和爆炸子弹。
enum Type {
	UNKNOWN = -1,
	NORMAL,
	PIERCING,
	EXPLOSIVE,
}


## 将配置字符串转换为子弹类型；无法识别时返回 UNKNOWN。
static func from_string(value: String) -> Type:
	match value.strip_edges().to_upper():
		"NORMAL":
			return Type.NORMAL
		"PIERCING":
			return Type.PIERCING
		"EXPLOSIVE":
			return Type.EXPLOSIVE
		_:
			return Type.UNKNOWN


## 从装备 Attr 字典读取 BULLET_TYPE；旧配置缺少该字段时兼容为 NORMAL。
static func from_attr(attr: Dictionary) -> Type:
	if not attr.has("BULLET_TYPE"):
		return Type.NORMAL
	return from_string(str(attr["BULLET_TYPE"]))
