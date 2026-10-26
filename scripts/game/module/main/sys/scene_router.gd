class_name SceneRouter
extends Node
## 隔离第三方切场插件。先实例化，再在新场景入树、子节点 ready 前提交状态。

signal completed(success: bool)

var busy: bool = false
var _prepared: Node


func is_busy() -> bool:
	return busy or SceneManager._in_transition


func prepare(scene_name: String) -> bool:
	if is_busy():
		return false
	var entry: Dictionary = Scenes.scenes.get(scene_name, {})
	var path: String = entry.get("value", "")
	if path.is_empty() or not ResourceLoader.exists(path, "PackedScene"):
		return false
	var scene := load(path) as PackedScene
	if scene == null or not scene.can_instantiate():
		return false
	if is_instance_valid(_prepared):
		_prepared.free()
	_prepared = scene.instantiate()
	return _prepared != null


func start(commit: Callable, out_options, in_options, options) -> void:
	assert(is_instance_valid(_prepared) and not busy)
	busy = true
	var target := _prepared
	_prepared = null
	target.tree_entered.connect(commit, CONNECT_ONE_SHOT)
	_transition.call_deferred(target, out_options, in_options, options)


func _transition(target: Node, out_options, in_options, options) -> void:
	await SceneManager.change_scene(target, out_options, in_options, options)
	var success := is_instance_valid(target) and get_tree().current_scene == target
	if not success and is_instance_valid(target) and not target.is_inside_tree():
		target.free()
	busy = false
	completed.emit(success)


func _exit_tree() -> void:
	if is_instance_valid(_prepared):
		_prepared.free()
