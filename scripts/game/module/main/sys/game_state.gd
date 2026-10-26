extends Node
## 单例：游戏状态管理器，维护全局状态机和运行数据

@export var fade_out_speed: float = 0.5
@export var fade_in_speed: float = 0.5
@export var fade_out_pattern: String = "squares"
@export var fade_in_pattern: String = "squares"
@export var fade_out_smoothness = 0.5 # (float, 0, 1)
@export var fade_in_smoothness = 0.5 # (float, 0, 1)
@export var fade_out_inverted: bool = false
@export var fade_in_inverted: bool = true
@export var color: Color = Color(0.7, 0.1, 0)
@export var timeout: float = 0.5
@export var clickable: bool = false
@export var add_to_back: bool = true

@onready var fade_out_options = SceneManager.create_options(fade_out_speed, fade_out_pattern, fade_out_smoothness, fade_out_inverted)
@onready var fade_in_options = SceneManager.create_options(fade_in_speed, fade_in_pattern, fade_in_smoothness, fade_in_inverted)
@onready var general_options = SceneManager.create_general_options(color, timeout, clickable, add_to_back)

signal phase_changed(phase: RunState.Phase)
signal settlement_ready(settlement: RunSettlement)
signal request_failed(message: String)

var _run := RunState.new()
var _settlement: RunSettlement
var _router := SceneRouter.new()
var _next_run_id: int = 0
var _next_settlement_id: int = 0
var _executing: bool = false
var _previous_phase: RunState.Phase
var _error_dialog: AcceptDialog
var last_error: String = ""

var current_character_id: int:
	get: return _run.character_id
var total_gold_collected: int:
	get: return _run.collected_gold
var run_id: int:
	get: return _run.run_id
var phase: RunState.Phase:
	get: return _run.phase


func _ready() -> void:
	add_child(_router)
	_router.completed.connect(_on_transition_completed)
	_error_dialog = AcceptDialog.new()
	_error_dialog.title = "暂时无法继续"
	add_child(_error_dialog)
	if not GameConfig.ensure_loaded():
		_report_config_failure.call_deferred()
	elif not GameConfig.get_diagnostics().is_empty():
		push_warning(GameConfig.get_diagnostics())


func is_busy() -> bool:
	return _executing or _router.is_busy()


func get_settlement() -> RunSettlement:
	return _settlement.snapshot() if _settlement != null else null


func show_character_select() -> bool:
	if is_busy() or phase != RunState.Phase.MENU:
		return false
	if not _ensure_config_ready():
		return false
	return _route("character_select", func(): _run.phase = RunState.Phase.CHARACTER_SELECT)


func start_run(character_id: int) -> bool:
	if is_busy() or phase not in [RunState.Phase.MENU, RunState.Phase.CHARACTER_SELECT]:
		return false
	return _start_run(character_id)


func _start_run(character_id: int) -> bool:
	if not _ensure_config_ready():
		return false
	# 使用独立状态预检初始背包，失败时保留正在展示的旧局。
	var validation := InventoryService.new(InventoryState.new(), ShopState.new(), ForgeState.new())
	if not validation.initialize(character_id).success or not MapManager.can_initialize(1):
		return _reject("无法开始对局：角色、背包或首张地图配置不完整。")
	return _route("gaming", _initialize_run.bind(character_id))


func _initialize_run(character_id: int) -> void:
	CombatManager.cleanup()
	_next_run_id += 1
	_run = RunState.new()
	_run.run_id = _next_run_id
	_run.character_id = character_id
	_run.phase = RunState.Phase.MAP
	_settlement = null
	BackpackManager.init_backpack(character_id)
	BackpackManager.set_gold(999)
	MapManager.init_map(1)


func enter_map_node(map_id: int, layer: int, index: int) -> bool:
	if is_busy() or phase != RunState.Phase.MAP:
		return false
	var node := MapManager.find_map_node(map_id, layer, index)
	if not MapManager.is_node_reachable(node):
		return false
	match node.node_type:
		"battle":
			if not CombatManager.can_start_config(node.config_id):
				return _reject("无法进入战斗：战斗配置不完整。")
			return _route("battle", func():
				MapManager.visit_node(node)
				_run.battle_id = -1
				_run.phase = RunState.Phase.BATTLE
			)
		"shop":
			_executing = true
			var key := "%s:%s:%s" % [map_id, layer, index]
			var result := BackpackManager.open_shop(key, node.config_id)
			if not result.success:
				_executing = false
				return _reject("无法进入商店：商品配置不完整。")
			MapManager.visit_node(node)
			_set_phase(RunState.Phase.SHOP)
			_executing = false
			return true
		"forge":
			_executing = true
			MapManager.visit_node(node)
			_set_phase(RunState.Phase.FORGE)
			_executing = false
			return true
	return _reject("无法进入未知类型的地图节点。")


func bind_battle(battle_id: int) -> bool:
	if phase != RunState.Phase.BATTLE or _run.battle_id != -1 or not CombatManager.is_current_battle(battle_id):
		return false
	_run.battle_id = battle_id
	return true


func complete_battle(result: BattleResult, source_run_id: int) -> bool:
	if phase != RunState.Phase.BATTLE or result == null or source_run_id != run_id:
		return false
	if result != CombatManager.last_result or result.battle_id != _run.battle_id:
		return false
	var node := MapManager.current_map_node
	if node == null or node.node_type != "battle" or node.config_id != result.config_id:
		return false
	_executing = true
	_settle(result.won)
	_executing = false
	return true


func leave_current_node() -> bool:
	if is_busy() or phase not in [RunState.Phase.SHOP, RunState.Phase.FORGE]:
		return false
	_executing = true
	BackpackManager.set_grid_purchase_mode(false)
	BackpackManager.clear_forge_selection()
	if MapManager.is_map_final_node():
		_run.battle_id = -1
		_settle(true)
	else:
		_set_phase(RunState.Phase.MAP)
	_executing = false
	return true


func continue_run(settlement_id: int) -> bool:
	if not _can_consume_settlement(settlement_id):
		return false
	match _settlement.next_action:
		RunSettlement.Action.RETURN_TO_MAP:
			return _route("gaming", _resume_map.bind(0))
		RunSettlement.Action.NEXT_MAP:
			var next_id := _settlement.next_map_id
			if not MapManager.can_initialize(next_id):
				return _reject("无法进入下一张地图：地图配置不完整。")
			return _route("gaming", _resume_map.bind(next_id))
	return false


func retry_run(settlement_id: int) -> bool:
	if not _can_consume_settlement(settlement_id) or _settlement.next_action != RunSettlement.Action.RETRY:
		return false
	return _start_run(current_character_id)


func return_to_menu() -> bool:
	if is_busy() or phase == RunState.Phase.MENU:
		return false
	return _route("main_menu", func():
		CombatManager.cleanup()
		BackpackManager.set_grid_purchase_mode(false)
		BackpackManager.clear_forge_selection()
		_settlement = null
		_run = RunState.new()
		MapManager.clear_map()
	)


func record_collected_gold(amount: int) -> void:
	if amount > 0 and phase == RunState.Phase.BATTLE:
		_run.collected_gold += amount


func _resume_map(next_map_id: int) -> void:
	if next_map_id > 0:
		MapManager.init_map(next_map_id)
	_run.battle_id = -1
	_settlement = null
	_run.phase = RunState.Phase.MAP


func _can_consume_settlement(id: int) -> bool:
	return not is_busy() and phase == RunState.Phase.SETTLEMENT and _settlement != null and _settlement.settlement_id == id and _settlement.run_id == run_id


func _settle(won: bool) -> void:
	_settlement = RunFlow.settle(_run, won, MapManager.is_map_final_node(), MapManager.get_next_map_id())
	_next_settlement_id += 1
	_settlement.settlement_id = _next_settlement_id
	_set_phase(RunState.Phase.SETTLEMENT)
	settlement_ready.emit(get_settlement())


func _route(scene_name: String, commit: Callable) -> bool:
	if not _router.prepare(scene_name):
		return _reject("无法切换场景，请检查场景资源：" + scene_name)
	_previous_phase = phase
	_executing = true
	_set_phase(RunState.Phase.TRANSITIONING)
	_router.start(commit, fade_out_options, fade_in_options, general_options)
	_executing = false
	return true


func _on_transition_completed(success: bool) -> void:
	if not success:
		_run.phase = _previous_phase
		_reject("场景切换失败，已保留原进度。")
	phase_changed.emit(phase)


func _set_phase(value: RunState.Phase) -> void:
	_run.phase = value
	phase_changed.emit(value)


func _reject(message: String) -> bool:
	last_error = message
	request_failed.emit(message)
	if DisplayServer.get_name() != "headless":
		_error_dialog.dialog_text = message
		_error_dialog.popup_centered()
	return false


func _ensure_config_ready() -> bool:
	if GameConfig.ensure_loaded():
		return true
	_report_config_failure()
	return false


func _report_config_failure() -> void:
	var details := GameConfig.get_diagnostics()
	printerr(details)
	var lines := details.split("\n")
	var preview := "\n".join(lines.slice(0, 8))
	if lines.size() > 8:
		preview += "\n另有 %d 条问题，完整信息见调试器或日志。" % (lines.size() - 8)
	_reject("游戏配置校验失败，请修正后重试。\n" + preview)


func find_player() -> Player:
	var player: Player = get_tree().get_first_node_in_group("player")
	if not player:
		DebugUtility.warn("GameState", "未找到 group=player 的节点")
	return player
