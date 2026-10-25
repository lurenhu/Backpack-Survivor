extends RefCounted
## 为独立实体测试提供真实生命周期入口，不绕过战斗状态校验。

static func create(owner: Node) -> BattleContext:
	var context := BattleContext.new()
	context.scene_root = owner
	context.enemy_container = Node2D.new()
	context.pickup_container = Node2D.new()
	var point := Marker2D.new()
	owner.add_child(context.enemy_container)
	owner.add_child(context.pickup_container)
	owner.add_child(point)
	context.spawn_points.append(point)
	return context


static func start(owner: Node) -> bool:
	CombatManager.cleanup()
	return CombatManager.start_battle(1, create(owner))
