class_name ConfigIssue
extends RefCounted
## record_index 为导入后的数据记录序号（从 1 开始），不是 CSV 物理行号。

var severity: StringName = &"error"
var code: StringName
var file: String
var record_index: int
var record_key: String
var field: String
var message: String


func describe() -> String:
	return "[%s/%s] %s 记录 %d (%s) 字段 %s：%s" % [severity, code, file, record_index, record_key, field, message]
