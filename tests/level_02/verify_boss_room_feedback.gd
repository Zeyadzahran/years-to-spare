extends "res://tests/level_02/verify_business_boss.gd"
## Real spawn events, time-aware feedback and arena supply overlaps.

func portal_glow() -> void:
	await fresh()
	boss.health.take_damage(410, player)
	await wait_stage(arena.Stage.SPAWNING)
	for i in 100:
		if arena._spawn_index > 0: break
		await frames(1)
	await get_tree().process_frame
	var gate: ReinforcementGate = arena.reinforcement_gate
	check(gate.spawn_glow > 0.7, "Enemy spawn did not light up portal")
	await frames(2)
	var camera: Camera2D = player.get_node("Camera2D")
	check(camera.offset.length() > 1.0, "Enemy spawn did not shake the camera")
	var saved: Array = arena.rewind_capture()
	var glow := gate.spawn_glow
	TimeService.mode = TimeService.Mode.STOPPED
	await frames(20)
	check(is_equal_approx(gate.spawn_glow, glow), "Spawn glow ignored Stop Time")
	TimeService.mode = TimeService.Mode.NORMAL
	await frames(12)
	check(gate.spawn_glow < glow, "Spawn glow did not decay")
	arena.rewind_apply(saved)
	check(is_equal_approx(gate.spawn_glow, glow), "Rewind failed to restore portal glow")
	await wait_stage(arena.Stage.WAVE)
	await frames(45)
	check(is_zero_approx(gate.spawn_glow), "Portal glow persisted after last spawn")
	print("ROOM_FEEDBACK portal: actual spawns, decay, freeze and rewind")

func transition_shakes() -> void:
	await fresh()
	var camera: Camera2D = player.get_node("Camera2D")
	boss.begin_intermission()
	await frames(3)
	check(camera.offset.length() > 4.0 and camera.offset.length() < 12.0, "Disappearance shake missing or excessive")
	var held := camera.offset
	var saved: Array = arena.rewind_capture()
	TimeService.mode = TimeService.Mode.STOPPED
	await frames(20)
	check(camera.offset == held, "Transition shake ignored Stop Time")
	TimeService.mode = TimeService.Mode.NORMAL
	await frames(20)
	check(camera.offset == Vector2.ZERO, "Transition shake did not settle")
	arena.rewind_apply(saved)
	check(camera.offset.is_equal_approx(held), "Rewind failed to restore transition shake")
	await frames(25)
	boss.resume_after_intermission(arena.to_global(Vector2(1100,639)))
	await frames(3)
	check(camera.offset.length() > 3.0, "Appearance shake missing")
	await frames(80)
	check(camera.offset == Vector2.ZERO, "Arrival shake did not settle")
	print("ROOM_FEEDBACK shake: departure, arrival, freeze, rewind and settle")

func healing_supplies() -> void:
	await fresh(false)
	player.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.health.max_health = 100.0
	var hearts := GameState.hearts
	var supplies := [arena.get_node("Platforms/StepOne/LeftSupply"), arena.get_node("Platforms/StepThree/RightSupply")]
	for chest in supplies:
		var platform := chest.get_parent() as MovingIndustrialPlatform
		var before := platform.global_position
		var snapshot := platform.rewind_capture()
		await frames(20)
		check(platform.global_position != before, "Supply platform did not move")
		check(chest.global_position.is_equal_approx(platform.global_position), "Healing supply detached from platform top")
		TimeService.mode = TimeService.Mode.STOPPED
		platform.rewind_apply(snapshot)
		# AnimatableBody2D commits its transform on the next physics sync.
		await frames(2)
		TimeService.mode = TimeService.Mode.NORMAL
		check(chest.global_position.is_equal_approx(before), "Healing supply failed to follow rewound platform")
		platform.set_physics_process(false)
		player.global_position = chest.global_position
		player.health.restore_to(100.0)
		await frames(4)
		# The lid may open for a heart at full health; the healing stays put.
		check(not chest.healed and player.health.current == 100.0, "Supply wasted at full health")
		player.health.restore_to(40.0)
		var saved_chest: Array = chest.rewind_capture()
		var saved_player := player.rewind_capture()
		await frames(4)
		check(chest.opened and player.health.current == 90.0, "Arena supply did not heal 50 HP")
		player.health.restore_to(40.0)
		await frames(4)
		check(player.health.current == 40.0, "Opened supply healed twice")
		TimeService.mode = TimeService.Mode.REWINDING
		chest.rewind_apply(saved_chest)
		player.rewind_apply(saved_player)
		check(not chest.healed and player.health.current == 40.0, "Rewind did not restore supply and health together")
		TimeService.mode = TimeService.Mode.NORMAL
		await frames(4)
		check(chest.healed and player.health.current == 90.0, "Rewound supply could not be collected again")
	# An arena chest may have rolled a heart this run and given it up.
	check(GameState.hearts >= hearts and GameState.hearts <= hearts + supplies.size(), "Supply changed remaining hearts")
	print("ROOM_FEEDBACK supplies: two real overlaps, full-health preservation, 50 HP, one use and rewind")

func _ready() -> void:
	await portal_glow()
	await transition_shakes()
	await healing_supplies()
	print("BOSS_ROOM_FEEDBACK_VERIFIED failures=%d" % failures)
	TimeService.reset()
	level.queue_free()
	await frames(2)
	get_tree().quit(1 if failures else 0)
