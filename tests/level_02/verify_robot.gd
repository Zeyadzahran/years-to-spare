extends Node
## Real Level 2 physics and player inputs, with other encounters disabled.
## godot --headless --path . --fixed-fps 60 tests/level_02/verify_robot.tscn

const MAP := preload("res://src/levels/level_02/level_02.tscn")
const BEAM := preload("res://src/actors/enemy/robot_beam.tscn")

var level: Level
var player: Player
var robot: Robot
var failures := 0
var deaths := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func fresh() -> void:
	for action in [&"attack", &"jump", &"time_rewind", &"time_stop", &"move_left", &"move_right"]:
		Input.action_release(action)
	if is_instance_valid(player):
		player.powers.cancel()
	if is_instance_valid(level):
		level.queue_free()
	for beam in get_tree().get_nodes_in_group(&"robot_beam"):
		beam.queue_free()
	await frames(2)
	TimeService.reset()
	GameState.clear_run_progress()
	level = MAP.instantiate()
	add_child(level)
	get_tree().current_scene = self
	player = level.get_node("Entities/Player")
	robot = level.get_node("Enemies/RoofRobot")
	level.get_node("World/Hazards").process_mode = Node.PROCESS_MODE_DISABLED
	for enemy in level.get_node("Enemies").get_children():
		if enemy != robot:
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
	# Keep a failed assertion from reloading the entire test runner.
	EventBus.player_died.disconnect(level._on_player_died)
	player.position = Vector2(3700, 512)
	await frames(12)
	deaths = 0


func shot(at: Vector2, direction := 1, speed := 1600.0) -> RobotBeam:
	var beam := BEAM.instantiate() as RobotBeam
	beam.position = at
	beam.setup(direction, speed)
	add_child(beam)
	return beam


func wall(at: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2, 180)
	shape.shape = rectangle
	body.add_child(shape)
	level.add_child(body)
	return body


func wait_for_charge() -> void:
	for i in 120:
		if robot.state == &"Attack":
			return
		await frames(1)
	check(false, "Robot did not charge at a nearby player")


func rewind_input() -> void:
	Input.action_press(&"time_rewind")
	await frames(2)
	Input.action_release(&"time_rewind")
	await frames(ceili((TimePowers.WIND_UP + TimeService.REWIND_SPAN / TimeService.REWIND_SPEED) * 60.0) + 6)


func behavior() -> void:
	await fresh()
	var post := robot.position
	await frames(90)
	check(robot.state == &"Idle", "Robot detected the player outside its range")
	check(robot.is_on_floor() and robot.position.distance_to(post) < 0.1, "Robot left its post")
	player.position = Vector2(3870, 300)
	player.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	player.process_mode = Node.PROCESS_MODE_DISABLED
	await frames(90)
	check(robot.state == &"Idle", "Robot targeted a different floor")
	player.position = Vector2(3870, 512)
	var cover := wall(Vector2(3970, 440))
	await frames(60)
	check(robot.state == &"Idle", "Robot detected the player through cover")
	cover.queue_free()
	await frames(2)
	await wait_for_charge()
	await frames(18)
	check(robot.charge.visible and get_tree().get_nodes_in_group(&"robot_beam").is_empty(), "Charge did not warn before firing")
	TimeService.mode = TimeService.Mode.STOPPED
	var elapsed := robot._state_elapsed
	var pose := robot.sprite.frame
	var glow := robot.charge.frame
	await frames(35)
	check(is_equal_approx(robot._state_elapsed, elapsed) and robot.sprite.frame == pose and robot.charge.frame == glow,
		"Stop Time did not freeze the robot and warning")
	TimeService.mode = TimeService.Mode.NORMAL
	# Cross behind during the charge: this shot keeps its promised direction.
	player.position = Vector2(4200, 422)
	await frames(30)
	var beams := get_tree().get_nodes_in_group(&"robot_beam")
	check(not beams.is_empty(), "Charge did not fire")
	check(robot.shot_audio.playing, "Robot shot did not start the beam sound")
	if not beams.is_empty():
		check(beams[0]._velocity.x < 0 and is_zero_approx(beams[0]._velocity.y), "Charged shot turned or aimed diagonally")
	# Stay above the beam, inside vertical detection, to observe repeated shots.
	await frames(160)
	check(get_tree().get_nodes_in_group(&"robot_beam").size() >= 2, "Robot did not repeat after cooldown")
	check(absf(robot.position.x - post.x) < 0.1, "Robot chased or moved between shots")
	print("ROBOT behavior: range, cover, charge, frozen animation, fixed direction, repeat, stationary")


func collisions() -> void:
	for direction in [-1, 1]:
		await fresh()
		robot.set_physics_process(false)
		player.position = Vector2(3870, 512)
		player.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
		player.process_mode = Node.PROCESS_MODE_DISABLED
		await frames(2)
		var beam := shot(Vector2(3870 - direction * 220, 442), direction, 24000.0)
		await frames(3)
		check(player.is_down(), "High-speed beam skipped the player, direction %d" % direction)
		check(not is_instance_valid(beam) or not beam.visible, "Beam remained active after a hit")
	await fresh()
	robot.set_physics_process(false)
	player.position = Vector2(4000, 512)
	player.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	player.process_mode = Node.PROCESS_MODE_DISABLED
	wall(Vector2(3900, 440))
	await frames(2)
	shot(Vector2(3760, 442), 1, 24000.0)
	await frames(5)
	check(player.health.is_alive(), "Fast beam passed through a thin wall")
	await fresh()
	robot.set_physics_process(false)
	var beam := shot(Vector2(3870, 442))
	TimeService.mode = TimeService.Mode.STOPPED
	await frames(2)
	var at := beam.position
	var phase := beam.sprite.frame
	await frames(90)
	check(beam.visible and beam.position == at and beam.sprite.frame == phase, "Stopped beam moved, animated or expired")
	player.position = Vector2(3870, 512)
	await frames(3)
	check(player.is_down(), "Walking into a stopped beam was harmless")
	print("ROBOT collision: fast hits both ways, thin wall, frozen beam contact")


func fatal_retry() -> void:
	await fresh()
	player.position = Vector2(3870, 512)
	robot.set_physics_process(false)
	await frames(250)
	var hearts := GameState.hearts
	robot.set_physics_process(true)
	for i in 120:
		if player.is_down():
			break
		await frames(1)
	check(player.is_down(), "The robot's actual shot did not kill the grounded player")
	await rewind_input()
	check(player.health.is_alive() and not player.is_down(), "Rewind did not undo the beam death")
	check(GameState.hearts == hearts and deaths == 0, "Rewound beam death consumed a heart or announced a death")
	check(get_tree().get_nodes_in_group(&"robot_beam").is_empty(), "Rewind left the fatal beam behind before its birth")
	await wait_for_charge()
	while robot.state == &"Attack" and robot._state_elapsed < 0.4:
		await frames(1)
	Input.action_press(&"jump")
	await frames(2)
	Input.action_release(&"jump")
	await frames(35)
	check(player.health.is_alive() and player.position.y < 470, "Jumping on the retry did not avoid the actual shot")
	print("ROBOT fatal retry: death, Rewind input, heart preserved, jump survives")


func sword_and_revival() -> void:
	await fresh()
	player.position = Vector2(4060, 512)
	player.facing = 1
	robot.set_physics_process(false)
	await frames(250)
	robot.set_physics_process(true)
	await wait_for_charge()
	var post := robot.position
	for swing in 3:
		Input.action_press(&"attack")
		await frames(2)
		Input.action_release(&"attack")
		await frames(16)
		check(absf(robot.position.x - post.x) < 0.1 and absf(robot.position.y - post.y) < 0.1, "Sword knocked the robot away")
		if swing < 2:
			check(robot.state == &"Hurt" and robot.health.is_alive(), "Sword hit did not interrupt charging with Hurt")
			check(robot.hurt_audio.playing, "Sword hit did not start the metal hit sound")
		else:
			check(robot.state == &"Dead", "Three sword hits did not kill the robot")
			check(robot.death_audio.playing, "Robot death did not start its sound")
		await frames(18)
	check(get_tree().get_nodes_in_group(&"robot_beam").is_empty(), "Interrupted robot still fired")
	await frames(50)
	check(not robot.visible and GameState.is_enemy_cleared(&"phase_2", "Enemies/RoofRobot"), "Death animation did not retire and clear robot")
	await rewind_input()
	check(robot.visible and robot.health.is_alive() and robot.state != &"Dead", "Rewind did not revive the robot")
	check(not GameState.is_enemy_cleared(&"phase_2", "Enemies/RoofRobot"), "Rewound robot remained cleared from the level")
	check(not robot.death_audio.playing, "Death sound continued after rewinding the robot alive")
	print("ROBOT sword: three real hits, charge interrupted, no knockback, death animation, revival")


func projectile_history() -> void:
	await fresh()
	robot.set_physics_process(false)
	await frames(250)
	var beam := shot(Vector2(3700, 170), 1, 400.0)
	await frames(60)
	var forward := beam.position.x
	TimeService.mode = TimeService.Mode.REWINDING
	await frames(10)
	check(beam.visible and beam.position.x < forward - 100, "Existing beam did not travel backward")
	TimeService.mode = TimeService.Mode.NORMAL
	var resumed := beam.position.x
	await frames(10)
	check(beam.position.x > resumed, "Rewound beam did not resume moving forward")
	await frames(35)
	check(not beam.visible, "Beam did not expire")
	TimeService.mode = TimeService.Mode.REWINDING
	await frames(12)
	check(beam.visible and not beam._spent, "Expired beam did not return during Rewind")
	TimeService.mode = TimeService.Mode.NORMAL
	print("ROBOT projectile history: backward motion, resume, expired beam restored")


func _ready() -> void:
	EventBus.player_died.connect(func(_old_age: bool) -> void: deaths += 1)
	await behavior()
	await collisions()
	await fatal_retry()
	await sword_and_revival()
	await projectile_history()
	print("LEVEL_02_ROBOT_VERIFIED failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
