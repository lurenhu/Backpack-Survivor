class_name Forge
extends Control
## 材料、预览和成品均从业务层读取；按钮只提交锻造请求。

const CARD_SCENE: PackedScene = preload("res://scene/shop/equipment_card.tscn")

@onready var result_name: Label = $ForgeResultCard/Label
@onready var result_equipment_card: EquipmentCard = $ForgeResultCard/CenterContainer/EquipmentCard
@onready var forge_table_grid_tile: TileMapLayer = $ForgeTableGrid/GridTile
@onready var forge_table_grid: Control = $ForgeTableGrid
@onready var forge_button: Button = $ForgeButton
@onready var exit_button: Button = $ExitButton
@onready var card_container: Control = $CardContainer

signal add_equipment_card(card: EquipmentCard)

var table_cards: Dictionary[Vector2i, EquipmentCard] = {}


func _ready() -> void:
	BackpackManager.forge_changed.connect(_update_view)
	BackpackManager.gold_changed.connect(_on_gold_changed)
	forge_button.pressed.connect(_on_forge_button_pressed)
	_update_view()


func show_merge_result_card() -> void:
	if result_equipment_card.is_interacting():
		return
	var reward := BackpackManager.get_pending_forge_reward()
	var preview_id := BackpackManager.get_forge_preview_id()
	forge_button.disabled = reward != null or preview_id == 0 or BackpackManager.gold < BackpackManager.get_forge_cost()
	forge_button.text = "锻造 (%d 金币)" % BackpackManager.get_forge_cost() if preview_id != 0 and reward == null else "锻造"
	if reward != null:
		result_equipment_card.setup_by_equipment(reward)
		result_equipment_card.set_preview_modulate(false)
	elif preview_id != 0:
		result_equipment_card.setup(preview_id, BackpackManager.GridType.FORGE_REWARD)
		result_equipment_card.set_preview_modulate(true)
	result_equipment_card.visible = reward != null or preview_id != 0
	result_name.text = result_equipment_card.equipment.name if result_equipment_card.visible else ""


func _update_view() -> void:
	_update_table_grid()
	var existing: Dictionary[int, EquipmentCard] = {}
	for card in table_cards.values():
		existing[card.equipment.instance_id] = card
	table_cards.clear()
	for equip in BackpackManager.get_forge_materials().values():
		var card: EquipmentCard = existing.get(equip.instance_id)
		if card == null:
			card = CARD_SCENE.instantiate()
			card_container.add_child(card)
			card.setup_by_equipment(equip)
			add_equipment_card.emit(card)
		else:
			existing.erase(equip.instance_id)
		if not card.is_interacting():
			card.setup_by_equipment(equip)
			card.position = BackpackManager.grid_to_pixel(equip.grid_pos, forge_table_grid, card_container) - card.get_rotate_offset()
		table_cards[equip.grid_pos] = card
	for card in existing.values():
		card.hide()
		card.queue_free()
	show_merge_result_card()


func _update_table_grid() -> void:
	forge_table_grid_tile.clear()
	var grid := BackpackManager.forge_grid
	for y in grid.size():
		for x in grid[y].size():
			forge_table_grid_tile.set_cell(Vector2i(x, y), 1, Vector2i.ZERO)


func _on_gold_changed(_gold: int) -> void:
	show_merge_result_card()


func _on_forge_button_pressed() -> void:
	BackpackManager.try_forge()
