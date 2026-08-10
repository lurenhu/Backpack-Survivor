class_name PanelManager
extends Control
## 商店场景：管理商店刷新、购买和关卡推进

@onready var shop: Shop = $Shop
@onready var package: Package = $Package
@onready var map: Control = $Map
@onready var panel_animation: AnimationPlayer = $PanelAnimation

func _ready() -> void:
	shop.hide()
	package.hide()
	map.show()
	
	for child_map in map.get_children():
		map.remove_child(child_map)
		child_map.queue_free()

	var map_scene: PackedScene = load("res://scene/map/map_%s.tscn" % MapManager.current_map_id)
	map.add_child(map_scene.instantiate())

	for card in shop.get_cards():
		card.drag_dropped.connect(_on_equipment_dropped.bind(card))
		package.register_dragging_card(card)
	
	shop.exit_button.pressed.connect(_on_exit_button_pressed)

#region 公开功能

## 打开商店
func show_shop() -> void:
	shop.set_equipment_pool()

	if panel_animation.is_playing():
		await panel_animation.animation_finished
	panel_animation.play("show_shop")

## 关闭商店
func hide_shop() -> void:
	if panel_animation.is_playing():
		await panel_animation.animation_finished
	panel_animation.play("hide_shop")

## 显示地图
func show_map() -> void:
	var map_scene: Map = map.get_child(0) as Map
	if map_scene == null:
		return
	map_scene.update_map_nodes()

	if panel_animation.is_playing():
		await panel_animation.animation_finished
	panel_animation.play("show_map")

## 关闭地图
func hide_map() -> void:
	if panel_animation.is_playing():
		await panel_animation.animation_finished
	panel_animation.play("hide_map")

## 显示背包
func show_package() -> void:
	if panel_animation.is_playing():
		await panel_animation.animation_finished
	panel_animation.play("show_package")

## 关闭背包
func hide_package() -> void:
	if panel_animation.is_playing():
		await panel_animation.animation_finished
	panel_animation.play("hide_package")

#endregion

#region 内部方法

## 拒绝放置：卡片归位
func _reject_drop(equipment: Equipment) -> void:
	match equipment.state:
		BackpackManager.GridType.SHOP:
			var card: EquipmentCard = shop.get_card_from_equip(equipment)
			if card:
				card.return_to_origin()

#endregion

#region 信号回调

## 装备拖拽放置处理：判断是否落在背包网格内，执行放置或归位
func _on_equipment_dropped(screen_position: Vector2, equipment_card: EquipmentCard) -> void:
	var origin_grid_type: BackpackManager.GridType = equipment_card.origin_equipment.state
	match origin_grid_type:
		BackpackManager.GridType.SHOP:
			if GameState.gold < equipment_card.equipment.price:
				equipment_card.return_to_origin()
				return

	# 判断背包对应区域是否可放置对应装备
	var can_place: bool = false
	var grid_pos: Vector2i = Vector2i(-1, -1)
	if package.backpack_container.get_global_rect().has_point(screen_position):
		grid_pos = BackpackManager.screen_to_grid(screen_position, package.backpack_container.global_position)
		equipment_card.equipment.state = BackpackManager.GridType.PACKAGE
	elif package.stage_container.get_global_rect().has_point(screen_position):
		grid_pos = BackpackManager.screen_to_grid(screen_position, package.stage_container.global_position)
		equipment_card.equipment.state = BackpackManager.GridType.STAGE
	else:
		equipment_card.return_to_origin()
		return
	equipment_card.equipment.grid_pos = grid_pos
	var new_equipment = equipment_card.equipment.copy()
	can_place = BackpackManager.add_to_equip_grid(new_equipment, grid_pos)

	# 实例化卡片
	match origin_grid_type:
		BackpackManager.GridType.SHOP:
			if can_place and GameState.gold >= equipment_card.equipment.price:
				GameState.gold -= equipment_card.equipment.price
				equipment_card.visible = false
			equipment_card.return_to_origin()


## 关闭隐藏商店界面
func _on_exit_button_pressed():
	hide_shop()
	show_map()

#endregion
