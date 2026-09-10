extends Node
## Tests the saved Level 2 with the real player controller and physics.
const MAP := preload("res://src/levels/level_02/level_02.tscn")
var level: Level
var player: Player
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func spawn() -> void:
	level = MAP.instantiate()
	add_child(level)
	player = level.get_node("Entities/Player")
	# Focus route checks on geometry, without removing any of its terrain.
	level.get_node("Enemies").process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("World/Hazards").process_mode = Node.PROCESS_MODE_DISABLED
	await frames(3)

func place(at: Vector2, age: float) -> void:
	Input.action_release("move_right")
	Input.action_release("move_left")
	Input.action_release("jump")
	player.position = at
	player.velocity = Vector2.ZERO
	player.age.set_to(age)
	player.health.heal(100)
	await frames(12)

func crossing(title: String, start: Vector2, takeoff_x: float, end_x: float, floor_y: float, age: float, brake := false, direction := 1) -> void:
	await place(start, age)
	check(player.is_on_floor(), title + " takeoff has no floor")
	var move_action := "move_right" if direction > 0 else "move_left"
	Input.action_press(move_action)
	for i in 90:
		await get_tree().physics_frame
		if (player.position.x - takeoff_x) * direction >= 0: break
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	var landed := false
	for i in 100:
		await get_tree().physics_frame
		if brake and (player.position.x - end_x) * direction > 0:
			Input.action_release(move_action)
		if (player.position.x - end_x) * direction > 0 and player.is_on_floor():
			landed = true
			break
		if player.position.y > 950: break
	Input.action_release(move_action)
	check(landed and player.position.y <= floor_y + 3, "%s age %.0f failed at %s" % [title,age,player.position])
	print("ROUTE %s age=%.0f landed=%s position=%s"%[title,age,landed,player.position])

func _ready() -> void:
	GameState.clear_run_progress()
	await spawn()
	check(GameState.current_level()["id"] == &"phase_2", "Direct scene selected wrong phase")
	check(level.get_node("Enemies").get_child_count() == 11, "Expected eleven enemies")
	level.get_node("Enemies").process_mode = Node.PROCESS_MODE_INHERIT
	await frames(240)
	for enemy in level.get_node("Enemies").get_children():
		check(enemy.is_on_floor(), "Enemy has no footing: " + String(enemy.name))
	level.get_node("Enemies").process_mode = Node.PROCESS_MODE_DISABLED
	for age in [14.0, 60.0]:
		await crossing("Street gap",Vector2(1300,640),1370,1635,640,age)
		await crossing("Roof approach",Vector2(2765,576),2842,3110,512,age)
		await crossing("Courtyard drop",Vector2(6080,512),6165,6440,640,age)
		await crossing("Exit gap",Vector2(7370,640),7450,7710,640,age)
		await crossing("Cargo obstacle",Vector2(1640,640),1705,1905,640,age)
		await crossing("Street cache step",Vector2(850,640),875,975,494,age,true)
		await crossing("Street cache",Vector2(1030,494),1090,1290,423,age,true)
		await crossing("Roof cache step",Vector2(4080,512),4120,4230,369,age,true)
		await crossing("Roof cache",Vector2(4300,369),4260,4110,267,age,true,-1)
	var ferry := level.get_node("World/Platforms/FreightShuttle") as MovingPlatform
	await place(ferry.position + Vector2(0,-12),14)
	var relative_x := player.position.x - ferry.position.x
	await frames(120)
	check(absf(player.position.x - ferry.position.x - relative_x) < 12, "Freight deck did not carry player")
	check(player.is_on_floor(), "Player fell through freight deck")
	TimeService.mode = TimeService.Mode.STOPPED
	var stopped_at := ferry.position
	await frames(30)
	check(ferry.position.distance_to(stopped_at) < 0.1, "Time stop did not hold freight deck")
	TimeService.reset()
	# The existing combat must work against the units placed in this scene.
	var guard := level.get_node("Enemies/StreetPatrol") as Guard
	await place(guard.position + Vector2(-40,0),14)
	player.facing = 1
	level.get_node("Enemies").process_mode = Node.PROCESS_MODE_INHERIT
	TimeService.mode = TimeService.Mode.STOPPED
	for swing in 4:
		Input.action_press("attack")
		await frames(2)
		Input.action_release("attack")
		await frames(38)
	await frames(90)
	check(GameState.is_enemy_cleared(&"phase_2","Enemies/StreetPatrol"), "Placed guard could not be defeated with real attacks")
	TimeService.reset()
	level.get_node("Enemies").process_mode = Node.PROCESS_MODE_DISABLED
	var trap := level.get_node("World/Hazards/YardPulse")
	trap.process_mode = Node.PROCESS_MODE_INHERIT
	level.get_node("World/Hazards").process_mode = Node.PROCESS_MODE_INHERIT
	# Keep the body in contact: Hurt knockback otherwise moves it out of the trap.
	player.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	player.process_mode = Node.PROCESS_MODE_DISABLED
	await place(trap.position,14)
	check(is_equal_approx(player.health.current,75), "Electricity did not hurt immediately on contact")
	var before := player.health.current
	await frames(65)
	check(player.health.current < before, "Electricity did not keep damaging an overlapping player")
	TimeService.mode = TimeService.Mode.STOPPED
	before = player.health.current
	await frames(65)
	check(player.health.current < before, "Time stop incorrectly disabled electricity")
	TimeService.reset()
	level.get_node("World/Hazards").process_mode = Node.PROCESS_MODE_DISABLED
	player.process_mode = Node.PROCESS_MODE_INHERIT
	await place(level.get_node("World/Supplies/YardSupply").position,14)
	player.health.take_damage(60)
	await frames(4)
	check(is_equal_approx(player.health.current,90), "Supply chest did not heal by 50")
	check(level.get_node("World/Supplies/YardSupply").opened, "Supply chest did not open")
	await frames(10)
	check(is_equal_approx(player.health.current,90), "Supply chest healed more than once")
	var checkpoint := level.get_node("World/Checkpoints/L2Rooftops")
	checkpoint._on_body_entered(player)
	GameState.run_age = 37.0
	GameState.clear_enemy(&"phase_2","Enemies/StreetPatrol")
	level.queue_free()
	await frames(2)
	await spawn()
	check(player.position.distance_to(Vector2(3200,512)) < 3, "Retry did not restore Level 2 checkpoint")
	check(is_equal_approx(player.age.age,37), "Retry refunded age")
	check(not level.has_node("Enemies/StreetPatrol"), "Defeated Level 2 enemy returned")
	check(level.get_node("World/Checkpoints/L2Rooftops/Marker").animation == &"green", "Checkpoint did not stay lit")
	var exit_area := level.get_node("World/Exit/LevelExit")
	check(exit_area.get_node("Completion/Panel/Copy/Title").text == "LEVEL 2 COMPLETE", "Exit copy still says Level 1")
	exit_area._on_body_entered(player)
	await get_tree().process_frame
	await get_tree().process_frame
	check(get_tree().paused and exit_area.get_node("Completion/Panel").visible, "Exit did not complete Level 2")
	get_tree().paused = false
	level.queue_free()
	await frames(2)
	GameState.start_new_run()
	check(GameState.current_level()["id"] == &"phase_1" and not GameState.has_checkpoint(&"phase_2"), "Level 2 retry leaked into Level 1")
	print("LEVEL_02_VERIFIED failures=%d"%failures)
	get_tree().quit(0 if failures == 0 else 1)
