extends Node
## Runs the risky shortcut in three controller-driven clusters while time is
## stopped, then checks that the real ability charges exactly three years.

const EXTENSION := "res://src/levels/level_01_production_extension.tscn"
const PLAYER := "res://src/actors/player/player.tscn"
const CLUSTERS := [
	[^"AgeCutLink01", ^"AgeCutFall01", ^"AgeCutBlink01", ^"AgeCutAnchor01"],
	[^"AgeCutAnchor01", ^"AgeCutFall02", ^"AgeCutBlink03", ^"AgeCutLink02"],
	[^"AgeCutLink02", ^"AgeCutBlink04", ^"AgeCutFall03", ^"AgeCutAnchor03"],
]


func _ready() -> void:
	GameState.start_new_run()
	var extension := (load(EXTENSION) as PackedScene).instantiate()
	add_child(extension)
	# Enemy bodies are audited separately; this gate isolates power-assisted
	# traversal while retaining the moving hazards themselves.
	extension.get_node(^"Enemies").free()
	await get_tree().physics_frame
	var platforms := extension.get_node(^"Platforms")

	# Each stable anchor is comfortably inside a five-second window even after
	# allowing 25% of the cast for jump arcs and correction.
	var cast_distance := 5.0 * 450.0 * 0.75
	for pair in [
		[^"AgeCutLink01", ^"AgeCutAnchor01"],
		[^"AgeCutAnchor01", ^"AgeCutLink02"],
		[^"AgeCutLink02", ^"AgeCutAnchor03"],
	]:
		var start := platforms.get_node(pair[0]) as Node2D
		var finish := platforms.get_node(pair[1]) as Node2D
		assert(finish.position.x - start.position.x <= cast_distance)

	TimeService.mode = TimeService.Mode.STOPPED
	for cluster: Array in CLUSTERS:
		if not await _cross_cluster(platforms, cluster):
			TimeService.reset()
			get_tree().quit(1)
			return
	TimeService.reset()

	# Exercise the real power once: input -> wind-up -> frozen world -> cost.
	var payer := (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(payer)
	await get_tree().process_frame
	var before := payer.age.age
	Input.action_press(&"time_stop")
	await get_tree().process_frame
	Input.action_release(&"time_stop")
	assert(payer.powers.is_winding_up())
	assert(is_equal_approx(payer.age.age, before + 3.0))
	# Feed the wind-up a deterministic real-clock slice; headless process frames
	# intentionally run faster than wall time and are unsuitable as a stopwatch.
	payer.powers._process(TimePowers.WIND_UP + 0.01)
	assert(TimeService.mode == TimeService.Mode.STOPPED)
	payer.powers.cancel()
	payer.free()
	print("AGE_CUT_OK clusters=3 planned_stops=3 planned_cost=9")
	get_tree().quit()


func _cross_cluster(platforms: Node, path: Array) -> bool:
	var player := (load(PLAYER) as PackedScene).instantiate() as Player
	var start = platforms.get_node(path[0])
	player.position = Vector2(start.position.x, start.position.y - start.size.y * 0.5 - 2.0)
	add_child(player)
	player.get_node(^"Camera2D").enabled = false
	player.age.set_to(23.0)
	for _frame in range(8):
		await get_tree().physics_frame

	for index in range(1, path.size()):
		var from = platforms.get_node(path[index - 1])
		var target = platforms.get_node(path[index])
		var launch_x: float = from.position.x + from.size.x * 0.5 - 8.0
		Input.action_press(&"move_right")
		for _frame in range(90):
			if player.position.x >= launch_x:
				break
			await get_tree().physics_frame
		Input.action_press(&"jump")
		await get_tree().physics_frame
		Input.action_release(&"jump")
		var landed := false
		var target_left: float = target.position.x - target.size.x * 0.5
		for _frame in range(100):
			await get_tree().physics_frame
			if player.is_on_floor() and player.position.x >= target_left + 14.0:
				landed = true
				break
			if player.position.y > target.position.y + 420.0:
				break
		Input.action_release(&"move_right")
		if not landed:
			push_error("Age Cut failed %s -> %s at %s" % [from.name, target.name, player.position])
			player.free()
			await get_tree().physics_frame
			return false
		for _frame in range(3):
			await get_tree().physics_frame
	player.free()
	await get_tree().physics_frame
	return true
