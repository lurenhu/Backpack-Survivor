class_name ConfigSnapshot
extends RefCounted
## 配置快照不包含任何对局数据。正式发布后，业务代码只读取其中的 Data 对象。

var equipment: Dictionary = {}
var monsters: Dictionary = {}
var characters: Dictionary = {}
var pickups: Dictionary = {}
var shops: Dictionary = {}
var forges: Dictionary = {}
var battles: Dictionary = {}
var map_nodes: Dictionary = {}
