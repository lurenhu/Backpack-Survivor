class_name NormalBullet
extends BulletBase
## 普通子弹，命中第一个合法目标后造成直接伤害并消失。


## 对目标造成直接伤害，然后结束子弹。
func _on_valid_target_hit(body: Node2D) -> void:
	_deal_damage(body, spec.direct_damage)
	_finish()
