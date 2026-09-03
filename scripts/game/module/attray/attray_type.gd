class_name AttrType
extends RefCounted
## 属性类型定义：枚举所有属性类型，提供默认值、CSV映射、容器运算


# 属性类型枚举——新增属性只需在此添加一项
enum Type {
	ATK, # 攻击力
	ATK_INC, # 攻击力增加
	ATK_GAIN, # 攻击力百分比
	HP, # 生命值上限
	SPD, # 移动速度
	CRIT_RATE, # 暴击率 (0~1)
	CRIT_DMG, # 暴击伤害倍率
	DEF, # 防御力
	ATK_SPEED, # 攻击速度倍率
	RANGE, # 攻击范围倍率
	COOLDOWN, # 冷却缩减 (0~1)
	LIFE_STEAL, # 吸血比例 (0~1)

	## 旋转装备参数
	ROTATE_SPEED, # 旋转速度
	ROTATE_SPEED_GAIN, # 旋转速度提高
	ROTATE_RADIUS, # 旋转半径
	ROTATE_RADIUS_GAIN, # 旋转半径提高

	## 发射装备参数
	SHOOT_NUM, # 发射数量
	SHOOT_INTERVAL, # 发射间隔
	SHOOT_INTERVAL_GAIN, # 发射间隔缩短百分比
	SHOOT_RADIUS, # 发射范围半径
	SHOOT_RADIUS_GAIN, # 发射范围半径扩大百分比
	BULLET_SPEED, # 子弹速度
	BULLET_SPEED_INC, # 子弹速度增加
	BULLET_SPEED_GAIN, # 子弹速度增加百分比
	PENETRATION_COUNT, # 穿透弹最多命中的敌人总数
	EXPLOSION_DAMAGE, # 爆炸范围伤害
	EXPLOSION_RADIUS, # 爆炸范围半径

	## 范围装备参数
	AREA_RADIUS, # 范围半径
	AREA_RADIUS_GAIN, # 范围扩大百分比
	AREA_INTERVAL, # 范围伤害频率
	AREA_INTERVAL_GAIN, # 范围伤害频率提高百分比
}

# 属性类型 → CSV键名映射（新增属性时同步添加）
const TYPE_TO_KEY: Dictionary = {
	Type.ATK: "ATK",
	Type.ATK_INC: "ATK_INC",
	Type.ATK_GAIN: "ATK_GAIN",
	Type.HP: "HP",
	Type.SPD: "SPD",
	Type.CRIT_RATE: "CRIT_RATE",
	Type.CRIT_DMG: "CRIT_DMG",
	Type.DEF: "DEF",
	Type.ATK_SPEED: "ATK_SPEED",
	Type.RANGE: "RANGE",
	Type.COOLDOWN: "COOLDOWN",
	Type.LIFE_STEAL: "LIFE_STEAL",
	Type.ROTATE_SPEED: "ROTATE_SPEED",
	Type.ROTATE_SPEED_GAIN: "ROTATE_SPEED_GAIN",
	Type.ROTATE_RADIUS: "ROTATE_RADIUS",
	Type.ROTATE_RADIUS_GAIN: "ROTATE_RADIUS_GAIN",
	Type.SHOOT_NUM: "SHOOT_NUM",
	Type.SHOOT_INTERVAL: "SHOOT_INTERVAL",
	Type.SHOOT_INTERVAL_GAIN: "SHOOT_INTERVAL_GAIN",
	Type.SHOOT_RADIUS: "SHOOT_RADIUS",
	Type.SHOOT_RADIUS_GAIN: "SHOOT_RADIUS_GAIN",
	Type.BULLET_SPEED: "BULLET_SPEED",
	Type.BULLET_SPEED_INC: "BULLET_SPEED_INC",
	Type.BULLET_SPEED_GAIN: "BULLET_SPEED_GAIN",
	Type.PENETRATION_COUNT: "PENETRATION_COUNT",
	Type.EXPLOSION_DAMAGE: "EXPLOSION_DAMAGE",
	Type.EXPLOSION_RADIUS: "EXPLOSION_RADIUS",
	Type.AREA_RADIUS: "AREA_RADIUS",
	Type.AREA_RADIUS_GAIN: "AREA_RADIUS_GAIN",
	Type.AREA_INTERVAL: "AREA_INTERVAL",
	Type.AREA_INTERVAL_GAIN: "AREA_INTERVAL_GAIN",
}

# 各属性类型的默认值（新增属性时同步添加）
const DEFAULTS: Dictionary = {
	Type.ATK: 0.0,
	Type.ATK_INC: 0.0,
	Type.ATK_GAIN: 0.0,
	Type.HP: 0.0,
	Type.SPD: 0.0,
	Type.CRIT_RATE: 0.0,
	Type.CRIT_DMG: 0.0,
	Type.DEF: 0.0,
	Type.ATK_SPEED: 0.0,
	Type.RANGE: 0.0,
	Type.COOLDOWN: 0.0,
	Type.LIFE_STEAL: 0.0,
	Type.ROTATE_SPEED: 0.0,
	Type.ROTATE_SPEED_GAIN: 0.0,
	Type.ROTATE_RADIUS: 0.0,
	Type.ROTATE_RADIUS_GAIN: 0.0,
	Type.SHOOT_NUM: 0.0,
	Type.SHOOT_INTERVAL: 0.0,
	Type.SHOOT_INTERVAL_GAIN: 0.0,
	Type.SHOOT_RADIUS: 0.0,
	Type.SHOOT_RADIUS_GAIN: 0.0,
	Type.BULLET_SPEED: 0.0,
	Type.BULLET_SPEED_INC: 0.0,
	Type.BULLET_SPEED_GAIN: 0.0,
	Type.PENETRATION_COUNT: 1.0,
	Type.EXPLOSION_DAMAGE: 0.0,
	Type.EXPLOSION_RADIUS: 0.0,
	Type.AREA_RADIUS: 0.0,
	Type.AREA_RADIUS_GAIN: 0.0,
	Type.AREA_INTERVAL: 0.0,
	Type.AREA_INTERVAL_GAIN: 0.0,
}

# CSV键名 → 属性类型反向映射
static var _key_to_type: Dictionary = {}
static var _key_map_built: bool = false


# 属性反向映射
static func _ensure_key_map() -> void:
	if _key_map_built:
		return
	for type in TYPE_TO_KEY:
		_key_to_type[TYPE_TO_KEY[type]] = type
	_key_map_built = true


# 获取属性类型对应的CSV键名
static func get_key(type: Type) -> String:
	return TYPE_TO_KEY.get(type, "")


# 从CSV键名获取属性类型，无效键名返回 -1
static func get_type(key: String) -> Type:
	_ensure_key_map()
	return _key_to_type.get(key, -1)


# 从CSV字典构建属性容器
static func from_csv_dict(raw: Dictionary) -> AttrContainer:
	_ensure_key_map()
	var container := AttrContainer.new()
	for key in raw:
		var type: Type = _key_to_type.get(key, -1)
		if type != -1:
			container.set_value(type, float(raw[key]))
	return container


# 创建预填充默认值的属性容器
static func create_default() -> AttrContainer:
	var container := AttrContainer.new()
	for type in DEFAULTS:
		container.set_value(type, DEFAULTS[type])
	return container
