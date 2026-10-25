class_name Shop
extends Control
## 货架只是业务状态的显示，出售状态不依赖卡牌是否可见。

@onready var refresh_button: Button = $RefreshButton
@onready var grid_button: Button = $GridButton
@onready var exit_button: Button = $ExitButton

const CARD_COUNT: int = ShopState.CARD_COUNT
var _cards: Array[EquipmentCard] = []
var _name_labels: Array[Label] = []


func _ready() -> void:
	for i in range(1, CARD_COUNT + 1):
		_cards.append(get_node("Market/Commodity_%d/CenterContainer/EquipmentCard" % i))
		_name_labels.append(get_node("Market/Commodity_%d/EquipName/Name" % i))
	refresh_button.pressed.connect(refresh_shop)
	grid_button.toggle_mode = true
	grid_button.toggled.connect(_on_grid_button_toggled)
	BackpackManager.grid_purchase_state_changed.connect(_update_grid_button)
	BackpackManager.shop_changed.connect(update_view)
	_update_grid_button()
	update_view()


func get_cards() -> Array[EquipmentCard]:
	return _cards.duplicate()


func set_equipment_pool() -> void:
	var node := MapManager.current_map_node
	if node == null:
		return
	var key := "%s:%s:%s" % [node.map_id, node.layer_index, node.node_index]
	BackpackManager.open_shop(key, node.config_id)
	update_view()


func refresh_shop(item_ids: Array[int] = []) -> void:
	BackpackManager.refresh_shop(item_ids)


func update_view() -> void:
	var offers := BackpackManager.get_shop_offers()
	for i in _cards.size():
		var card := _cards[i]
		if card.is_interacting():
			continue
		if i >= offers.size():
			card.hide()
			_name_labels[i].text = ""
			continue
		var offer: Dictionary = offers[i]
		card.setup(offer.config_id)
		card.offer_id = offer.offer_id
		card.visible = not offer.sold
		_name_labels[i].text = card.equipment.name if not offer.sold else ""


func _on_grid_button_toggled(enabled: bool) -> void:
	BackpackManager.set_grid_purchase_mode(enabled)


func _update_grid_button() -> void:
	grid_button.set_pressed_no_signal(BackpackManager.is_grid_purchase_mode)
	grid_button.text = "退出购买" if BackpackManager.is_grid_purchase_mode else "购买网格"
