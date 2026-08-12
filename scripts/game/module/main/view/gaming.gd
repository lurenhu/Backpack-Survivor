extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var panel_manager: PanelManager = $PanelManager

## 播放背景着色
@export var speed: float = 10
var timer: float

func _ready() -> void:
	MapManager.map_node_seleceted.connect(_on_map_node_selected)

func _process(delta: float) -> void:
	var panel_material = panel.material as ShaderMaterial
	timer += delta * speed
	panel_material.set_shader_parameter("time_val", timer)

#region 信号回调

## 选择地图节点：记录目标节点信息，标记已访问，跳转对应场景
func _on_map_node_selected(map_node: MapNode) -> void:
	MapManager.current_map_node = map_node
	match map_node.node_type:
		"shop":
			panel_manager.hide_map()
			panel_manager.show_shop()
		"battle":
			GameState.change_scene("battle")
		"forge":
			panel_manager.hide_map()
			panel_manager.show_forge()
		_:
			DebugUtility.error("can not find node type", "%s" % map_node.node_type)

#endregion