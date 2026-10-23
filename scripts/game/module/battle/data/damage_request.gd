class_name DamageRequest
extends RefCounted
## 一次伤害请求；source 表示直接造成伤害的武器、子弹或角色，可为空。

var source: Node = null
var target: Node = null
var amount: float = 0.0


static func create(damage_source: Node, damage_target: Node, damage_amount: float) -> DamageRequest:
	var request := DamageRequest.new()
	request.source = damage_source
	request.target = damage_target
	request.amount = damage_amount
	return request
