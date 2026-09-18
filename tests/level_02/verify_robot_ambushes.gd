extends Node
## Exercise the three authored ambushes through real Area2D overlaps and time history.
## Run headless with --fixed-fps 60 tests/level_02/verify_robot_ambushes.tscn.

const MAP := preload("res://src/levels/level_02/level_02.tscn")
const PAIRS := [["CoverRobot", "CoverAmbush"], ["DropRobot", "DropAmbush"], ["CeilingRobot", "CeilingAmbush"]]

var level: Level
var player: Player
var failures := 0
var shots := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func fresh() -> void:
	TimeService.reset()
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
	# Hold a real player body still so overlaps and sight tests remain real,
	# while its own rewind cannot carry it out of the overlap being tested.
	player.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.remove_from_group(TimeService.REWINDABLE_GROUP)
	player.position = Vector2(8200, 640)
	level.get_node("Enemies").process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("World/Hazards").process_mode = Node.PROCESS_MODE_DISABLED
	EventBus.player_died.disconnect(level._on_player_died)
	await frames(90)

func dormant(robot: Robot, context: String) -> void:
	check(not robot.visible, context + ": inactive robot is visible")
	check(robot.process_mode == Node.PROCESS_MODE_DISABLED, context + ": inactive robot is ticking")
	check(robot.collision_layer == 0, context + ": inactive robot blocks the player")

func untouched_history() -> void:
	await fresh()
	for pair in PAIRS:
		dormant(level.get_node("Ambushes/" + pair[0]), pair[0] + " on load")
	TimeService.mode = TimeService.Mode.REWINDING
	await frames(20)
	TimeService.mode = TimeService.Mode.NORMAL
	await frames(2)
	for pair in PAIRS:
		dormant(level.get_node("Ambushes/" + pair[0]), pair[0] + " before first activation")

func upper_route_and_frozen_crossing() -> void:
	await fresh()
	var platform_robot: Robot = level.get_node("Ambushes/DropRobot")
	player.position = Vector2(9530, 369)
	await frames(20)
	check(platform_robot.visible and platform_robot.process_mode == Node.PROCESS_MODE_INHERIT,
		"Platform robot did not activate from the upper route")
	await fresh()
	var cover_robot: Robot = level.get_node("Ambushes/CoverRobot")
	TimeService.mode = TimeService.Mode.STOPPED
	player.position = level.get_node("Ambushes/CoverAmbush").position
	await frames(12)
	player.position = Vector2(9300, 640)
	await frames(12)
	dormant(cover_robot, "Crossed the entire trigger during time stop")
	TimeService.mode = TimeService.Mode.NORMAL
	await frames(20)
	check(cover_robot.visible and cover_robot.process_mode == Node.PROCESS_MODE_INHERIT,
		"Ambush forgot the player crossed during time stop")

func encounter(pair: Array) -> void:
	await fresh()
	var robot: Robot = level.get_node("Ambushes/" + pair[0])
	var trigger: Area2D = level.get_node("Ambushes/" + pair[1])
	trigger.anticipation_time = 0.5
	TimeService.mode = TimeService.Mode.STOPPED
	player.position = trigger.position
	await frames(45)
	dormant(robot, pair[0] + " entered during time stop")
	TimeService.mode = TimeService.Mode.NORMAL
	await frames(10)
	dormant(robot, pair[0] + " during warning")
	var elapsed: float = trigger._elapsed
	TimeService.mode = TimeService.Mode.STOPPED
	await frames(45)
	check(is_equal_approx(trigger._elapsed, elapsed), pair[0] + ": warning advanced during time stop")
	dormant(robot, pair[0] + " warning paused")
	TimeService.mode = TimeService.Mode.NORMAL
	await frames(25)
	check(robot.visible and robot.process_mode == Node.PROCESS_MODE_INHERIT and robot.collision_layer == 4,
		pair[0] + ": did not activate after time resumed")
	# Rewind past the original entry, leaving the player already inside.
	TimeService.mode = TimeService.Mode.REWINDING
	await frames(55)
	dormant(robot, pair[0] + " rewound before activation")
	TimeService.mode = TimeService.Mode.NORMAL
	await frames(40)
	check(robot.visible and robot.process_mode == Node.PROCESS_MODE_INHERIT and robot.collision_layer == 4,
		pair[0] + ": overlap did not reactivate after rewind")
	for other in PAIRS:
		if other != pair:
			dormant(level.get_node("Ambushes/" + other[0]), other[0] + " after another ambush rewound")
	# Let falling robots reach their authored floor, then give each turret a
	# target at its own height. Ground targets are intentionally below the platform gun.
	player.collision_layer = 0
	player.position = Vector2(8200, 640)
	await frames(75)
	check(robot.is_on_floor(), pair[0] + ": did not settle on its floor")
	player.position = robot.position + Vector2(-190, 0)
	for i in 180:
		if robot.state == &"Attack" and robot._state_elapsed >= 0.15:
			break
		await frames(1)
	check(robot.state == &"Attack", pair[0] + ": did not charge after reactivation")
	TimeService.mode = TimeService.Mode.STOPPED
	await frames(2)
	var clock := robot._state_elapsed
	var pose := robot.sprite.frame
	var glow := robot.charge.frame
	var shots_before := shots
	await frames(40)
	check(is_equal_approx(robot._state_elapsed, clock) and robot.sprite.frame == pose and robot.charge.frame == glow,
		pair[0] + ": charging animation advanced during time stop")
	check(shots == shots_before, pair[0] + ": shot during time stop")
	TimeService.mode = TimeService.Mode.NORMAL
	await frames(45)
	check(shots > shots_before, pair[0] + ": remained frozen instead of firing after time stop")
	# Stay within active history; a rewind during combat must restore a live,
	# collidable turret and allow its attack clock to run forward again.
	TimeService.mode = TimeService.Mode.REWINDING
	await frames(10)
	TimeService.mode = TimeService.Mode.NORMAL
	var restored_clock := robot._state_elapsed
	shots_before = shots
	await frames(5)
	check(robot.visible and robot.process_mode == Node.PROCESS_MODE_INHERIT and robot.collision_layer == 4,
		pair[0] + ": combat rewind left an inert sprite")
	check(not is_equal_approx(robot._state_elapsed, restored_clock), pair[0] + ": combat clock did not resume")
	await frames(160)
	check(shots > shots_before, pair[0] + ": did not fire again after combat rewind")
	print("ROBOT_AMBUSH %s: stop, rewind before activation, reactivation, combat resume" % pair[0])

func _ready() -> void:
	child_entered_tree.connect(func(node: Node) -> void:
		if node is RobotBeam:
			shots += 1)
	await untouched_history()
	await upper_route_and_frozen_crossing()
	for pair in PAIRS:
		await encounter(pair)
	print("ROBOT_AMBUSHES_VERIFIED failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
