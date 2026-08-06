extends Node
## 单例：游戏状态管理器，维护全局状态机和运行数据

enum GameStep {MAIN_MENU, CHARACTER, UPGRADE, BATTLE}

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

var current_state: GameStep = GameStep.MAIN_MENU
var current_character_id: int = 0
var total_gold_collected: int = 0
var gold: int = 0

func _ready() -> void:
	GameConfig._init()


## 切换场景
func change_scene(scene_name: String) -> void:
	SceneManager.change_scene(scene_name, fade_out_options, fade_in_options, general_options)


## 开始新一局游戏
func start_new_run(character_id: int) -> void:
	current_character_id = character_id
	total_gold_collected = 0
	gold = 10
	BackpackManager.init_backpack(character_id)
	MapManager.init_map(1)


## 增加金币
func add_gold(amount: int) -> void:
	total_gold_collected += amount
	gold += amount


## 查找玩家节点
func find_player() -> Player:
	var player: Player = get_tree().get_first_node_in_group("player")
	if not player:
		DebugUtility.warn("GameState", "未找到 group=player 的节点")
	return player
