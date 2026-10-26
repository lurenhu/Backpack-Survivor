class_name RunState
extends RefCounted
## 对局只保存流程状态；地图、背包、单场战斗各自保留唯一数据源。

enum Phase { MENU, CHARACTER_SELECT, MAP, SHOP, FORGE, BATTLE, SETTLEMENT, TRANSITIONING }

var run_id: int = 0
var character_id: int = 0
var phase: Phase = Phase.MENU
var collected_gold: int = 0
var battle_id: int = -1
