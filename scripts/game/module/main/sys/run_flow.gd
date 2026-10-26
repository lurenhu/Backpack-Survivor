class_name RunFlow
extends RefCounted
## 纯规则：根据结果决定下一步，不读取界面，也不推进地图。

static func settle(run: RunState, won: bool, final_node: bool, next_map_id: int) -> RunSettlement:
	var result := RunSettlement.new()
	result.run_id = run.run_id
	result.battle_id = run.battle_id
	result.won = won
	result.collected_gold = run.collected_gold
	if not won:
		result.next_action = RunSettlement.Action.RETRY
	elif not final_node:
		result.next_action = RunSettlement.Action.RETURN_TO_MAP
	elif next_map_id > 0:
		result.next_action = RunSettlement.Action.NEXT_MAP
		result.next_map_id = next_map_id
	else:
		result.next_action = RunSettlement.Action.END_RUN
	return result
