extends Node2D
## 装配战斗场景；规则和计时统一由 CombatManager 驱动。

@onready var _battle_ui: BattleUI = get_node_or_null("BattleUI") as BattleUI
@onready var _enemy_container: Node2D = $EnemyContainer
@onready var _pick_up_container: Node2D = $PickUpContainer
@onready var bullet_container: Node2D = $BulletContainer
@onready var _bullet_spawner: BulletSpawner = $BulletSpawner

var _battle_id: int = -1


func _ready() -> void:
	var context := BattleContext.new()
	context.scene_root = self
	context.enemy_container = _enemy_container
	context.pickup_container = _pick_up_container
	for child in $EnemySpawner.get_children():
		if child is Marker2D:
			context.spawn_points.append(child)

	_bullet_spawner.setup(bullet_container)
	CombatManager.battle_stopped.connect(_stop_gameplay)
	CombatManager.battle_ended.connect(_on_battle_ended)
	CombatManager.projectile_requested.connect(_bullet_spawner.spawn)
	var map_node = MapManager.current_map_node
	if map_node == null or not CombatManager.start_battle(map_node.config_id, context):
		_disconnect_signals()
		_stop_gameplay()
		push_error("Battle: invalid configuration/context or previous battle has not been cleaned up")
		return
	_battle_id = CombatManager.battle_id


func _process(delta: float) -> void:
	if CombatManager.is_current_battle(_battle_id):
		CombatManager.tick_combat(delta)


func _exit_tree() -> void:
	if _battle_id == CombatManager.battle_id:
		CombatManager.cleanup()
	_disconnect_signals()


func _stop_gameplay() -> void:
	set_process(false)
	_bullet_spawner.cleanup()
	# 避免在碰撞回调中移除物理对象；入口校验会立即拒绝新的战斗操作。
	for node in [_enemy_container, _pick_up_container, bullet_container, get_node_or_null("Node/Player")]:
		if is_instance_valid(node):
			node.set_deferred("process_mode", Node.PROCESS_MODE_DISABLED)


func _disconnect_signals() -> void:
	if CombatManager.battle_stopped.is_connected(_stop_gameplay):
		CombatManager.battle_stopped.disconnect(_stop_gameplay)
	if CombatManager.battle_ended.is_connected(_on_battle_ended):
		CombatManager.battle_ended.disconnect(_on_battle_ended)
	if is_instance_valid(_bullet_spawner) and CombatManager.projectile_requested.is_connected(_bullet_spawner.spawn):
		CombatManager.projectile_requested.disconnect(_bullet_spawner.spawn)


func _on_battle_ended(result: BattleResult) -> void:
	if result.battle_id == _battle_id and is_instance_valid(_battle_ui):
		_battle_ui.show_game_over(result.won)
