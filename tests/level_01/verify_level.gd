extends Node
## The live merged scene: original seam and the real one-way boss gate overlap.

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

	var gate := section.get_node(^"Gates/BossGate") as BossGate
	var non_player := Node2D.new()
	gate._on_body_entered(non_player)
	non_player.free()
	assert(not gate.get("_transitioning"))
	assert(completions.is_empty())
	var gate_shape := gate.get_node(^"Shape") as CollisionShape2D
	player.global_position = gate_shape.global_position + Vector2(0, 50)
	player.velocity = Vector2.ZERO
	player.age.set_to(23)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(gate.get("_transitioning"))
	assert(player.process_mode == Node.PROCESS_MODE_DISABLED)
	await get_tree().create_timer(1.35).timeout
	var arena := level.get_node(^"World/BossArena") as BossArena
	var spawn := arena.get_node(^"PlayerSpawn") as Marker2D
	assert(player.global_position.distance_to(spawn.global_position) < 4.0)
	assert(arena.boss.active)
	assert(completions.is_empty())
	assert(TimeService.mode == TimeService.Mode.NORMAL)
	assert(player.powers.active == null)
	gate._on_body_entered(player)
	await get_tree().process_frame
	assert(player.global_position.distance_to(spawn.global_position) < 4.0)
	assert(completions.is_empty())
	print("BOSS_GATE_OK overlap=player transfer=once power_cancelled=true")
	level.queue_free()
	await get_tree().process_frame
	get_tree().quit()
