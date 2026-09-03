class_name RadialShooter
extends ShooterBase
## 固定径向发射器，始终沿远离所属角色中心的方向发射。


## 自动射击计时器超时时，以当前固定位置计算向外方向并发射。
func _on_shoot_timeout() -> void:
	if not auto_fire or source == null:
		return
	request_fire(global_position - source.global_position)
