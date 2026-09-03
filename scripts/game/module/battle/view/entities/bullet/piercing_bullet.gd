class_name PiercingBullet
extends BulletBase
## 穿透子弹，可依次伤害配置数量的不同目标。

## 当前已经命中的不同目标数量。
var _hit_count: int = 0


## 对目标造成直接伤害，并在达到最大命中总数后结束子弹。
func _on_valid_target_hit(body: Node2D) -> void:
	_deal_damage(body, spec.direct_damage)
	_hit_count += 1
	if _hit_count >= maxi(spec.max_hit_count, 1):
		_finish()
