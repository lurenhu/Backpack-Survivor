class_name RunSettlement
extends RefCounted
## 展示用值快照。界面拿到的是副本，不能改写正式结算。

enum Action { RETURN_TO_MAP, NEXT_MAP, RETRY, END_RUN }

var settlement_id: int = 0
var run_id: int = 0
var battle_id: int = -1
var won: bool = false
var collected_gold: int = 0
var next_action: Action = Action.RETRY
var next_map_id: int = 0


func snapshot() -> RunSettlement:
	var copy := RunSettlement.new()
	copy.settlement_id = settlement_id
	copy.run_id = run_id
	copy.battle_id = battle_id
	copy.won = won
	copy.collected_gold = collected_gold
	copy.next_action = next_action
	copy.next_map_id = next_map_id
	return copy
