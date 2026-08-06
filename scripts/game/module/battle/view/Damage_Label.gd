class_name DamageLabel
extends Label
## 伤害数字：显示伤害数值并向上漂移淡出

@export var float_distance: float = 80.0
@export var fade_duration: float = 0.8

## 设置伤害数值并启动漂移淡出动画
func setup(damage: int) -> void:
	text = str(damage)

	var font_size: int = int(clampf(16.0 + (damage - 5) * 32 / 45.0, 16.0, 48.0))
	if label_settings == null:
		var new_settings := LabelSettings.new()
		new_settings.font_size = font_size
		new_settings.font_color = Color(0, 1, 1, 1)
		new_settings.outline_size = 5
		new_settings.outline_color = Color(0, 0, 0, 1)
		label_settings = new_settings
	else:
		label_settings.font_size = font_size

	var tween: Tween = create_tween()
	tween.set_parallel()
	tween.tween_property(self, "position:y", position.y - float_distance, fade_duration)
	tween.tween_property(self, "modulate:a", 0.0, fade_duration).from(1.0)
	tween.chain().tween_callback(queue_free)
