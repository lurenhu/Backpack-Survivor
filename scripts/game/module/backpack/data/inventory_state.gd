class_name InventoryState
extends RefCounted
## 服务持有正式对象；外部查询通过管理器取得快照。

var gold: int = 0
var items: Dictionary[int, Equipment] = {}
var grids: Dictionary[int, Array] = {}
var grid_cost: int = 10
var purchase_mode: bool = false
