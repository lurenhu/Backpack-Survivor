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
		card.drag_dropped.connect(_on_equipment_dropped)
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
	var card: EquipmentCard = shop.get_card_from_equip(equipment)
	if card:
		card.return_to_origin()

#endregion

#region 信号回调

## 装备拖拽放置处理：判断是否落在背包网格内，执行放置或归位
func _on_equipment_dropped(equipment: Equipment, screen_position: Vector2) -> void:
	var grid_pos: Vector2i = Vector2i(-1, -1)
	var target_type: int = -1 # 0=backpack, 1=stage

	var pakage_rect: Rect2 = $Package/PakageGrid.get_global_rect()
	var stage_rect: Rect2 = $Package/StageGrid.get_global_rect()

	if pakage_rect.has_point(screen_position):
		grid_pos = BackpackManager.screen_to_grid(screen_position, $Package/PakageGrid.global_position)
		target_type = 0
	elif stage_rect.has_point(screen_position):
		grid_pos = BackpackManager.screen_to_grid(screen_position, $Package/StageGrid.global_position)
		target_type = 1

	if grid_pos.x < 0 or grid_pos.y < 0:
		# 未落在任何网格内，归位
		_reject_drop(equipment)
		return

	# 扣金币
	var config: EquipmentData = GameConfig.equipment[equipment.config_id]
	var price: int = config.price
	if GameState.gold < price:
		_reject_drop(equipment)
		return
	GameState.gold -= price

	# 拷贝一份装备数据用于放置，避免修改商店卡片的原始引用
	var equip: Equipment = equipment.copy()

	# 执行放置
	var placed: bool = false
	if target_type == 0:
		placed = BackpackManager.add_to_backpack(equip, grid_pos)
	else:
		placed = BackpackManager.add_to_stage(equip, grid_pos)

	if placed:
		var card: EquipmentCard = shop.get_card_from_equip(equipment)
		if card:
			card.visible = false
			card.return_to_origin()
	else:
		# 放置失败，归还金币
		GameState.gold += price
		_reject_drop(equipment)


## 关闭隐藏商店界面
func _on_exit_button_pressed():
	hide_shop()
	show_map()

#endregion
