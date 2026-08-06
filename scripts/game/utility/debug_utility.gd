class_name DebugUtility
extends RefCounted
## 调试输出工具类：统一管理终端调试日志，支持开关、标签和分级的日志输出

static var enabled: bool = true

enum Level {
	DEBUG = 0,
	INFO,
	WARN,
	ERROR
}

static var _level_colors: Dictionary = {
	Level.DEBUG: "#808080",
	Level.INFO: "#ffffff",
	Level.WARN: "#ffcc00",
	Level.ERROR: "#ff4444"
}

static var _level_names: Dictionary = {
	Level.DEBUG: "DEBUG",
	Level.INFO: "INFO",
	Level.WARN: "WARN",
	Level.ERROR: "ERROR"
}

static func debug(tag: String, message) -> void:
	## 输出调试日志
	_log(Level.DEBUG, tag, message)

static func info(tag: String, message) -> void:
	## 输出信息日志
	_log(Level.INFO, tag, message)

static func warn(tag: String, message) -> void:
	## 输出警告日志
	_log(Level.WARN, tag, message)

static func error(tag: String, message) -> void:
	## 输出错误日志
	_log(Level.ERROR, tag, message)

static func _log(level: Level, tag: String, message) -> void:
	## 统一日志输出，格式：[级别][标签] 内容
	if not enabled:
		return

	var color: String = _level_colors.get(level, "#ffffff")
	var level_name: String = _level_names.get(level, "LOG")
	var text: String = message as String
	print_rich("[color=%s][%s][%s][/color] %s" % [color, level_name, tag, text])
