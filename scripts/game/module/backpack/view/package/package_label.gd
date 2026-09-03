class_name PackageLabel
extends Label
## 背包网格购买价格：显示价格，并在购买成功后向上漂移淡出

@export var float_distance: float = 48.0
@export var fade_duration: float = 0.8


## 显示当前网格购买价格
func show_cost(cost: int) -> void:
	text = str(cost)
	modulate.a = 1.0


## 播放购买成功后的上浮淡出动画
func play_purchase_animation() -> void:
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(self, "position:y", position.y - float_distance, fade_duration)
	tween.tween_property(self, "modulate:a", 0.0, fade_duration).from(1.0)
	tween.chain().tween_callback(queue_free)
