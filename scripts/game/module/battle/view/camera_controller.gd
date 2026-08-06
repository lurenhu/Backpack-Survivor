class_name CameraController
extends Camera2D
## 相机控制器：带死区阈值的贝塞尔曲线平滑跟随主角

## 相机跟随权重，值越大跟随越缓慢
@export var weight: float = 100.0
## 相机默认系数
@export var default: float = 2.0

var _player: Player
var _locate_target: Node2D
var _locate_timer: float = 0.0

func _ready() -> void:
	call_deferred("_init_camera")

func _process(delta: float) -> void:
	if _locate_target:
		_locate_timer -= delta
		global_position = global_position.lerp(_locate_target.global_position, 1.0 - exp(-default * delta))
		if _locate_timer <= 0.0:
			_locate_target = null
		return

	if not _player:
		return

	var player_pos: Vector2 = _player.global_position

	var target: Vector2
	target = player_pos
	## 指数平滑插值：lerp(1 - exp(-speed*dt)) 等效贝塞尔缓出曲线，帧率无关
	global_position = global_position.lerp(target, 1.0 - exp(- (_player.attrs.get_value(AttrType.Type.SPD) / weight) * delta))

## ----内部方法----

## 延迟初始化：等待所有节点_ready完成后查找Player
func _init_camera() -> void:
	offset = Vector2.ZERO
	_player = _find_player()
	if _player:
		global_position = _player.global_position

## 查找场景中的玩家节点
func _find_player() -> Player:
	var player: Player = get_tree().get_first_node_in_group("player")
	if not player:
		DebugUtility.warn("camera", "未找到 group=player 的节点")
	return player

## ----公开功能----

## 定位至目标节点位置，根据默认系数平滑滑动至目标，经过time秒后重新跟随玩家
func locate_target(target: Node2D, time: float) -> void:
	_locate_target = target
	_locate_timer = time
