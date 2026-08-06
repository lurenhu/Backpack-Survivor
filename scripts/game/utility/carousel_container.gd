@tool
class_name CarouselContainer
extends Node2D

@export var spacing: float = 20.0

@export var warp_arraound_enable: bool = false
@export var warp_arraound_radius: float = 200.0
@export var warp_arraound_height: float = 30.0

@export_range(0.0, 1.0) var opacity_strength: float = .35
@export_range(0.0, 1.0) var scale_strenght: float = .25
@export_range(0.01, 0.99, 0.01) var scale_min: float = .1

@export var smoothing_speed: float = 6.5
@export var selected_index: int = 0
@export var follow_button_focus: bool = false

@export var position_offset_node: Control = null

func _process(delta: float) -> void:
	if not position_offset_node or position_offset_node.get_child_count() == 0:
		return

	selected_index = clamp(selected_index, 0, position_offset_node.get_child_count() - 1)

	for i in position_offset_node.get_children():
		if warp_arraound_enable:
			var max_index_range = max(1, (position_offset_node.get_child_count() - 1) / 2.0)
			var angle = clamp((i.get_index() - selected_index) / max_index_range, -1.0, 1.0) * PI
			var x = sin(angle) * warp_arraound_radius
			var y = cos(angle) * warp_arraound_height
			var target_position = Vector2(x, y - warp_arraound_height) - i.size / 2.0
			i.position = lerp(i.position, target_position, smoothing_speed * delta)
		else:
			var position_x = 0
			if i.get_index() > 0:
				position_x = position_offset_node.get_child(i.get_index() - 1).position.x + position_offset_node.get_child(i.get_index() - 1).size.x + spacing
			i.position = Vector2(position_x, -i.size.y / 2.0)

		i.pivot_offset = i.size / 2.0
		var target_scale = 1.0 - (scale_strenght * abs(i.get_index() - selected_index))
		target_scale = clamp(target_scale, scale_min, 1.0)
		i.scale = lerp(i.scale, Vector2.ONE * target_scale, smoothing_speed * delta)

		var target_opacity = 1.0 - (opacity_strength * abs(i.get_index() - selected_index))
		target_opacity = clamp(target_opacity, 0.0, 1.0)
		i.modulate.a = lerp(i.modulate.a, target_opacity, smoothing_speed * delta)

		if i.get_index() == selected_index:
			i.z_index = 1
		else:
			i.z_index = - abs(i.get_index() - selected_index)

		if follow_button_focus and i.has_focus():
			selected_index = i.get_index()

	if warp_arraound_enable:
		position_offset_node.position.x = lerp(
			position_offset_node.position.x,
			0.0,
			smoothing_speed * delta)
	else:
		position_offset_node.position.x = lerp(
			position_offset_node.position.x,
			- (position_offset_node.get_child(selected_index).position.x + position_offset_node.get_child(selected_index).scale.x / 2.0),
			smoothing_speed * delta)

func _left():
	selected_index -= 1
	if selected_index < 0:
		selected_index += 1

func _right():
	selected_index += 1
	if selected_index > position_offset_node.get_child_count() - 1:
		selected_index -= 1