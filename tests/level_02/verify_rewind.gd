extends Node
## Run with: godot --headless --path . --fixed-fps 60 tests/level_02/verify_rewind.tscn
## (a one-node scene with this script on it, like the other level_02 checks).
## Casts the rewind in the saved Level 2 with the real player, units and
## physics, and checks that the world actually went back: the boy to where he
## was, a downed unit to its feet, a fired round into the barrel - and that a
## death he rewinds out of costs him no heart.

const MAP := "res://src/levels/level_02/level_02.tscn"

var level: Level
var player: Player
var failures := 0
var deaths := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func release_all() -> void:
	for action in ["move_right", "move_left", "jump", "time_rewind", "time_stop"]:
		Input.action_release(action)


func spawn() -> void:
	GameState.clear_run_progress()
	level = (load(MAP) as PackedScene).instantiate()
	add_child(level)
	# The ghost layer is dropped into the current scene; in a test that is us.
	get_tree().current_scene = self
	player = level.get_node("Entities/Player")
	EventBus.player_died.connect(func(_old_age: bool) -> void: deaths += 1)
	await frames(3)


## One press, then the flourish and the window run out.
func cast_rewind() -> void:
	Input.action_press("time_rewind")
	await frames(2)
	Input.action_release("time_rewind")
	var duration: float = TimePowers.WIND_UP + TimeService.REWIND_SPAN / TimeService.REWIND_SPEED
	await frames(ceili(duration * 60.0) + 6)


func _ready() -> void:
	await spawn()
	check(GameState.has_ability(GameState.ABILITY_REWIND), "Phase 2 did not grant rewind")
	check(GameState.has_ability(GameState.ABILITY_STOP), "Phase 2 lost time stop")
	# Keep the units out of the first checks; they get their own below.
	level.get_node("Enemies").process_mode = Node.PROCESS_MODE_DISABLED

	# 1. Ground covered comes back. Long enough standing still that the four
	#    seconds reach into it, two seconds of running right, then the rewind.
	player.position = Vector2(600, 640)
	player.velocity = Vector2.ZERO
	await frames(240)
	var start := player.position
	var age_before: float = player.age.age
	Input.action_press("move_right")
	await frames(120)
	Input.action_release("move_right")
	var far := player.position
	check(far.x - start.x > 300.0, "Player did not cover ground before the rewind: %s -> %s" % [start, far])
	await cast_rewind()
	check(TimeService.mode == TimeService.Mode.NORMAL, "Rewind did not let go of the world")
	check(player.position.distance_to(start) < 64.0, "Player was not returned: wanted %s, at %s" % [start, player.position])
	check(is_equal_approx(player.age.age, age_before + 4.0), "Rewind did not cost four years: %.1f -> %.1f" % [age_before, player.age.age])
	check(player.states.current_name != &"Dead", "Player came out of the rewind dead")
	check(player.is_physics_processing(), "Player physics left off after the rewind")
	print("REWIND ground start=%s far=%s back=%s" % [start, far, player.position])

	# 2. A death rewound is no death. Killed outright mid-run, L pressed during
	#    the collapse: he stands back up, the heart stays, the level stays.
	await frames(int(TimePowers.WIND_UP * 60.0) + 400)
	player.position = Vector2(600, 640)
	player.velocity = Vector2.ZERO
	await frames(240)
	var hearts_before := GameState.hearts
	var health_before: float = player.health.current
	Input.action_press("move_right")
	await frames(60)
	Input.action_release("move_right")
	player.health.kill(null)
	await frames(10)
	check(player.states.current_name == &"Dead", "Kill did not put the player in Dead")
	await cast_rewind()
	check(deaths == 0, "A rewound death was still announced")
	check(player.states.current_name != &"Dead", "Player is still dead after the rewind")
	check(player.health.is_alive() and is_equal_approx(player.health.current, health_before),
		"Health was not handed back: %.0f (had %.0f)" % [player.health.current, health_before])
	check(GameState.hearts == hearts_before, "A rewound death cost a heart")
	check(absf(player.position.x - 600.0) < 300.0, "Rewound death left him where he died: %s" % player.position)
	check(is_instance_valid(level) and level.is_inside_tree(), "Level reloaded under a rewound death")
	print("REWIND death health=%.0f hearts=%d deaths=%d" % [player.health.current, GameState.hearts, deaths])

	# 3. A downed unit stands back up. Wait for the dying clip so it has
	#    actually retired, then reach back past the blow.
	await frames(400)
	level.get_node("Enemies").process_mode = Node.PROCESS_MODE_INHERIT
	var guard := level.get_node("Enemies/YardGuard") as Enemy
	player.position = guard.position + Vector2(-250.0, 0.0)
	player.velocity = Vector2.ZERO
	await frames(240)
	var guard_pos := guard.position
	var tag := String(level.get_path_to(guard))
	guard.health.take_damage(100.0, player)
	await frames(60)
	check(not guard.visible, "Downed unit did not retire after its dying clip")
	check(GameState.is_enemy_cleared(&"phase_2", tag), "Downed unit was not recorded as cleared")
	await cast_rewind()
	check(is_instance_valid(guard), "Downed unit was freed instead of kept for the rewind")
	if is_instance_valid(guard):
		check(guard.visible and guard.state != &"Dead" and guard.health.is_alive(),
			"Downed unit did not stand back up: visible=%s state=%s health=%.0f" % [guard.visible, guard.state, guard.health.current])
		check(guard.position.distance_to(guard_pos) < 96.0, "Revived unit is out of place: %s vs %s" % [guard.position, guard_pos])
	check(not GameState.is_enemy_cleared(&"phase_2", tag), "Revived unit is still recorded as cleared")
	print("REWIND enemy state=%s health=%.0f" % [guard.state if is_instance_valid(guard) else &"freed", guard.health.current if is_instance_valid(guard) else -1.0])

	# 4. A round fired inside the window goes back into the barrel.
	await frames(400)
	var bullet := preload("res://src/actors/enemy/bullet.tscn").instantiate() as Bullet
	level.add_child(bullet)
	bullet.global_position = player.global_position + Vector2(-2000.0, -60.0)
	bullet.setup(Vector2(0.0, 0.0), 0.0, null)
	await frames(30)
	await cast_rewind()
	check(not is_instance_valid(bullet) or bullet.is_queued_for_deletion(), "A round fired inside the window survived the rewind")
	print("REWIND bullet freed=%s" % (not is_instance_valid(bullet) or bullet.is_queued_for_deletion()))

	# 5. Stop still works as it did.
	await frames(400)
	Input.action_press("time_stop")
	await frames(2)
	Input.action_release("time_stop")
	await frames(int(TimePowers.WIND_UP * 60.0) + 10)
	check(TimeService.mode == TimeService.Mode.STOPPED, "Time stop no longer engages")
	player.powers.cancel()
	check(TimeService.mode == TimeService.Mode.NORMAL, "Cancel did not release the world")

	release_all()
	print("LEVEL_02_REWIND_VERIFIED failures=%d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
