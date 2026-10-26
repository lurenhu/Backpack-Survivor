extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var panel_manager: PanelManager = $PanelManager

## 播放背景着色
@export var speed: float = 10
var timer: float

var _game_over: GameOver

func _ready() -> void:
	GameState.phase_changed.connect(_on_phase_changed)
	_on_phase_changed(GameState.phase)


func _process(delta: float) -> void:
	var panel_material = panel.material as ShaderMaterial
	timer += delta * speed
	panel_material.set_shader_parameter("time_val", timer)


func _on_phase_changed(phase: RunState.Phase) -> void:
	panel_manager.present_phase(phase)
	if phase == RunState.Phase.SETTLEMENT:
		if not is_instance_valid(_game_over):
			_game_over = preload("res://scene/main/game_over.tscn").instantiate() as GameOver
			add_child(_game_over)
		_game_over.show_game_over(GameState.get_settlement())
