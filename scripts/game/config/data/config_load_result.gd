class_name ConfigLoadResult
extends RefCounted

var snapshot: ConfigSnapshot
var issues: Array[ConfigIssue] = []
var success: bool:
	get: return snapshot != null and not has_errors()


func has_errors() -> bool:
	for issue in issues:
		if issue.severity == &"error":
			return true
	return false


func add_issue(code: StringName, file: String, record_index: int, key: String, field: String, message: String, severity: StringName = &"error") -> void:
	var issue := ConfigIssue.new()
	issue.code = code
	issue.file = file
	issue.record_index = record_index
	issue.record_key = key
	issue.field = field
	issue.message = message
	issue.severity = severity
	issues.append(issue)


func describe() -> String:
	var lines := PackedStringArray()
	for issue in issues:
		lines.append(issue.describe())
	return "\n".join(lines)
