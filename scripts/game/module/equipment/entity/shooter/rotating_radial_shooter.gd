class_name RotatingRadialShooter
extends ShooterBase
## 旋转径向发射器；所在 ShooterRing 负责旋转，本节点沿实时径向方向发射。


## 自动射击计时器超时时，以旋转后的世界位置计算向外方向并发射。
func _on_shoot_timeout() -> void:
	if not auto_fire or source == null:
		return
	request_fire(global_position - source.global_position)
