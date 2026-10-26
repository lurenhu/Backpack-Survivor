extends SceneTree
## 用已登记的主场景路径完成 SceneManager 的启动校验，再加载独立测试场景。

func _initialize() -> void:
	var bootstrap := Node.new()
	bootstrap.scene_file_path = "res://scene/main/main_menu.tscn"
	root.add_child(bootstrap)
	current_scene = bootstrap
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Missing test scene")
		quit(1)
		return
	var packed_scene := load(args[0]) as PackedScene
	if packed_scene == null:
		quit(1)
		return
	var bootstrap := current_scene
	var test_scene := packed_scene.instantiate()
	root.add_child(test_scene)
	current_scene = test_scene
	bootstrap.queue_free()
	create_timer(15.0).timeout.connect(func():
		push_error("Test timeout: " + args[0])
		quit(1)
	)
