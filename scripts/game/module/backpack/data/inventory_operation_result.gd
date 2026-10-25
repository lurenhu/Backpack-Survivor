class_name InventoryOperationResult
extends RefCounted

var success: bool = false
var reason: StringName = &""
var inventory_changed: bool = false
var gold_changed: bool = false
var shop_changed: bool = false
var forge_changed: bool = false
var grid_changed: bool = false
var added_ids: Array[int] = []
var removed_ids: Array[int] = []
var moved_ids: Array[int] = []
var affected_grids: Array[int] = []


static func accepted() -> InventoryOperationResult:
	var result := InventoryOperationResult.new()
	result.success = true
	return result


static func rejected(cause: StringName) -> InventoryOperationResult:
	var result := InventoryOperationResult.new()
	result.reason = cause
	return result
