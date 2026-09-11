extends Node
## The live merged scene: original seam, real gate overlap, and completion UI.

const LEVEL := "res://src/levels/level_01/level_01.tscn"
var completions: Array[StringName] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.clear_run_progress()
	EventBus.level_completed.connect(func(id: StringName): completions.append(id))
	var level := (load(LEVEL) as PackedScene).instantiate()
	add_child(level)
	await get_tree().physics_frame
	var section := level.get_node(^"World/SalvageYard") as Node2D
	assert(section.scene_file_path.is_empty() and section.owner == level)
	assert(section.position.is_equal_approx(Vector2.ZERO))
	var player := get_tree().get_first_node_in_group(&"player") as Player
	player.health.max_health = 1.0e9
	player.health.current = 1.0e9
	player.age.set_to(59.0)
	player.position = Vector2(11710, 180)
	player.velocity = Vector2.ZERO
	for _frame in range(25):
		await get_tree().physics_frame
	Input.action_press(&"move_right")
	Input.action_press(&"jump")
	await get_tree().physics_frame
	Input.action_release(&"jump")
	var crossed := false
	for _frame in range(90):
		await get_tree().physics_frame
		if player.position.x >= 11950 and player.is_on_floor():
			crossed = true
			break
	Input.action_release(&"move_right")
	assert(crossed, "Opening no longer joins the later section")
	print("LEVEL_JOIN_TRAVERSAL_OK age=59 time_stops=0")

	var gate := section.get_node(^"Gates/LevelExit") as Area2D
	var non_player := Node2D.new()
	gate._on_body_entered(non_player)
	non_player.free()
	assert(not gate.get("_completed"))
	assert(completions.is_empty())
	player.position = gate.global_position + Vector2(-220, -2)
	player.velocity = Vector2.ZERO
	player.age.set_to(23)
	for _frame in range(12):
		await get_tree().physics_frame
	Input.action_press(&"time_stop")
	# process_frame resumes before nodes process input; allow that full frame.
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(&"time_stop")
	player.powers._process(TimePowers.WIND_UP + 0.01)
	assert(TimeService.mode == TimeService.Mode.STOPPED)
	Input.action_press(&"move_right")
	for _frame in range(90):
		await get_tree().physics_frame
		if not completions.is_empty():
			break
	Input.action_release(&"move_right")
	await get_tree().process_frame
	assert(completions == [&"phase_1"], "Gate overlap did not complete exactly once")
	assert(get_tree().paused)
	assert(TimeService.mode == TimeService.Mode.NORMAL)
	assert(player.powers.active == null)
	var panel := gate.get_node(^"Completion/Panel") as Control
	assert(panel.visible)
	var button := gate.get_node(^"Completion/Panel/Copy/ReturnButton") as Button
	assert(button.has_focus() and button.pressed.get_connections().size() == 1)
	assert(ResourceLoader.exists("res://src/ui/main_menu/main_menu.tscn"))
	var hud := level.get_node(^"HUD")
	assert(hud.options_button.disabled)
	hud._on_options_pressed()
	var pause_input := InputEventAction.new()
	pause_input.action = &"pause"
	pause_input.pressed = true
	hud._unhandled_input(pause_input)
	assert(hud.get("_options_panel") == null and get_tree().paused)
	gate._on_body_entered(player)
	await get_tree().process_frame
	assert(completions.size() == 1)
	print("LEVEL_EXIT_OK overlap=player completion=once power_cancelled=true options_locked=true")
	get_tree().paused = false
	level.queue_free()
	await get_tree().process_frame
	get_tree().quit()
