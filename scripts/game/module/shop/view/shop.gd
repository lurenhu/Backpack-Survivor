class_name Shop
extends Control
## 商店面板：管理商品卡片列表、刷新和购买交互

@onready var refresh_button: Button = $RefreshButton
@onready var exit_button: Button = $ExitButton

const CARD_COUNT: int = 5

var _cards: Array[EquipmentCard] = []
var _name_labels: Array[Label] = []
var _equipment_pool: PackedInt32Array = []

## 就绪时收集5个货架的卡片和名称标签引用
func _ready() -> void:
	for i in range(1, CARD_COUNT + 1):
		var card: EquipmentCard = get_node("Market/Commodity_%d/CenterContainer/EquipmentCard" % i)
		var name_label: Label = get_node("Market/Commodity_%d/Name" % i)
		_cards.append(card)
		_name_labels.append(name_label)

	refresh_button.pressed.connect(refresh_shop)

#region 私有方法

## 从指定装备池中随机选取指定数量的装备ID。池子不足时随机填充至 count 个后打乱返回
func _roll_from_pool(count: int, pool: Array[int]) -> Array[int]:
	if pool.is_empty():
		return []
	var result: Array[int] = pool.duplicate()
	result.shuffle()
	if result.size() >= count:
		return result.slice(0, count)
	while result.size() < count:
		result.append(pool[randi() % pool.size()])
	result.shuffle()
	return result

#endregion

#region 信号回调

#endregion

#region 公开功能

## 获取所有商品卡片
func get_cards() -> Array[EquipmentCard]:
	return _cards.duplicate()

## 根据Equipment对象在商店内查找对应的卡片
func get_card_from_equip(equipment: Equipment) -> EquipmentCard:
	for card in _cards:
		if card.equipment == equipment:
			return card
	return null

func set_equipment_pool():
	var shop_config_id: int = MapManager.current_map_node.config_id
	var shop_config: ShopConfigData = GameConfig.shops[shop_config_id]
	_equipment_pool = shop_config.equipment_ids
	refresh_shop()

## 刷新商店：从指定装备ID列表随机选取填充货架，未指定时使用限定池
func refresh_shop(item_ids: Array[int] = []) -> void:
	if item_ids.is_empty():
		if not _equipment_pool.is_empty():
			item_ids = _roll_from_pool(CARD_COUNT, _equipment_pool)
	for i in range(CARD_COUNT):
		if i < item_ids.size():
			var config: EquipmentData = GameConfig.equipment[item_ids[i]]
			_cards[i].visible = true
			_cards[i].setup(item_ids[i])
			_name_labels[i].text = config.name
		else:
			_cards[i].visible = false

#endregion
