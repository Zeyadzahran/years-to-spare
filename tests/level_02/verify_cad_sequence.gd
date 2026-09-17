extends "res://tests/level_02/verify_business_boss.gd"
## Direct entry without an intro, the airborne chamber, and the final
## platform drop -> walk -> fade boundary for the future artwork cutscene.

func direct_entry() -> void:
	await fresh(false)
	var platform: MovingIndustrialPlatform = arena.get_node("Platforms/ArenaPlatform")
	var offset: Vector2 = arena.chamber.global_position - platform.global_position
	await frames(30)
	check(arena.chamber.global_position - platform.global_position == offset, "Chamber detached from its platform")
	arena.prepare_gate_entry(player)
	check(arena.stage == arena.Stage.FIGHTING, "Entry did not start combat directly")
	check(not arena.cinematic.active and not arena.cinematic.overlay.visible, "Removed intro still starts")
	check(player.process_mode != Node.PROCESS_MODE_DISABLED, "Entry locked player input")
	check(get_viewport().get_camera_2d() == player.get_node("Camera2D"), "Entry hijacked camera")
	check(boss.sprite.material == null and boss.sprite.scale == Vector2.ONE * BusinessBoss.COMBAT_ART_SCALE and boss.sprite.rotation == 0, "Boss still has distorted rendering")
	print("CAD direct entry: no intro, no input lock, original boss rendering")

func chamber_idle() -> void:
	await fresh(false)
	var chamber: Node2D = arena.chamber
	var pose: int = chamber.machine.frame
	await frames(12)
	check(chamber.machine.frame != pose, "Parents' idle animation did not advance")
	TimeService.mode = TimeService.Mode.STOPPED
	pose = chamber.machine.frame
	var at: Vector2 = chamber.global_position
	await frames(25)
	check(chamber.machine.frame == pose and chamber.global_position == at, "Chamber animation/platform ignored Stop Time")
	TimeService.mode = TimeService.Mode.NORMAL
	var saved: Array = chamber.rewind_capture()
	await frames(15)
	chamber.rewind_apply(saved)
	check(chamber.machine.frame == pose, "Rewind did not restore parents' idle pose")
	print("CAD chamber: animated suffering idle, frozen frame/platform, restored pose")

func drop_and_walk(riding := false, at_destination := false) -> void:
	await fresh()
	var platform: MovingIndustrialPlatform = arena.get_node("Platforms/ArenaPlatform")
	if riding:
		platform.set_physics_process(false)
		player.global_position = platform.global_position + Vector2(-155 if at_destination else -120, -1)
	else:
		player.global_position = arena.to_global(Vector2(600, 639))
	await frames(4)
	boss.health.kill(player)
	await wait_stage(arena.Stage.EXIT_WALK)
	check(not arena.cinematic.descent_audio.playing, "Platform drop sound started before the fall")
	var start := player.global_position
	var platform_y := platform.global_position.y
	var count := completions
	await frames(50)
	check(player.process_mode == Node.PROCESS_MODE_DISABLED, "Ending walk did not lock input")
	check(arena.cinematic.descent_audio.playing, "Descending pitch did not play during the platform drop")
	check(platform.global_position.y > platform_y and platform.global_position.y < 640, "Platform did not begin falling")
	if not riding:
		check(player.global_position.distance_to(start) < 1, "Player walked before the platform landed")
	else:
		check(absf(player.global_position.y - platform.global_position.y) < 5, "Player riding chamber was left in midair")
	check(completions == count, "Level completed before platform landed")
	await frames(85)
	check(not arena.cinematic.descent_audio.playing, "Descending pitch continued after landing")
	check(is_equal_approx(platform.global_position.y, 640), "Platform failed to land at arena floor")
	check(is_equal_approx(arena.chamber.global_position.y, 640), "Chamber did not land with platform")
	await frames(50)
	if riding:
		check(player.sprite.animation == &"idle", "Player already near chamber kept running in place")
		check(player.global_position.distance_to(arena.chamber.global_position + Vector2(-155, -1)) < 1, "Short approach took the full walk duration")
	await wait_stage(arena.Stage.COMPLETE, 700)
	check(completions == count + 1, "Walk did not complete the level once")
	check(player.global_position.distance_to(arena.chamber.global_position + Vector2(-155, -1)) < 1, "Player did not reach chamber")
	check(is_equal_approx(arena.cinematic.fade.color.a, 1), "Level ended without fade")
	check(player.facing == 1, "Player faces away from chamber")
	await frames(90)
	check(completions == count + 1, "Completed walk emitted level completion again")
	print("CAD drop/walk: landed, waited, reached chamber, fade, one completion; riding=%s" % riding)

func jump_down_and_walk(platform_name: String, side := 0.0) -> void:
	await fresh()
	var ledge: MovingIndustrialPlatform = arena.get_node("Platforms/" + platform_name)
	# Exercise the middle and both edges at different platform heights.
	for other: MovingIndustrialPlatform in arena.get_node("Platforms").get_children():
		other.set_physics_process(false)
		other.sync_to_physics = false
		other._progress = (side + 1.0) * 0.5
		other._update_position()
	player.global_position = ledge.global_position + Vector2(side * (ledge.width_tiles * 32.0 - 20.0), -1)
	await frames(4)
	boss.health.kill(player)
	await wait_stage(arena.Stage.EXIT_WALK)
	var count := completions
	var start_y := player.global_position.y
	var jumps := [0]
	player.jumped.connect(func(): jumps[0] += 1)
	var saw_rise := false
	var saw_landing := false
	var saw_walk := false
	var lowest_y := start_y
	var previous := player.global_position
	var crossed_platform := false
	var half_body := (player.shape.shape as RectangleShape2D).size.x * 0.5
	for i in 800:
		await frames(1)
		var current := player.global_position
		# Check actual frame-to-frame floor crossings, including the body's
		# width. The old fixed-distance hop crossed StepThree near its left edge.
		for other: MovingIndustrialPlatform in arena.get_node("Platforms").get_children():
			if other == arena.cinematic.platform:
				continue
			if previous.y < other.global_position.y and current.y >= other.global_position.y:
				var crossing_x := lerpf(previous.x, current.x, (other.global_position.y - previous.y) / (current.y - previous.y))
				crossed_platform = crossed_platform or absf(crossing_x - other.global_position.x) < other.width_tiles * 32.0 + half_body
		previous = current
		var clip := player.sprite.animation
		if clip == &"jump":
			saw_rise = saw_rise or player.global_position.y < start_y - 20.0
			lowest_y = minf(lowest_y, player.global_position.y)
			check(arena.cinematic.elapsed < 4.0, "Jump was stretched across the walk")
		elif clip == &"land":
			saw_landing = true
			check(absf(player.global_position.y - 639.0) < 1.0, "Landing pose played above ground")
		elif clip == &"run":
			saw_walk = true
			check(saw_landing, "Player started walking before landing")
			check(absf(player.global_position.y - 639.0) < 1.0, "Player floated while walking")
		if arena.stage == arena.Stage.COMPLETE: break
	var normal_height := player.jump_velocity * player.jump_velocity / (2.0 * player.gravity)
	check(absf(start_y - lowest_y - normal_height) < 2.0, "Ending jump differs from the normal jump height")
	var reached_on_landing: bool = is_zero_approx(arena.cinematic._walk_duration)
	check(jumps[0] == 1 and saw_rise and saw_landing and (saw_walk or reached_on_landing), "Expected one normal jump, landing, then walk if needed")
	check(not crossed_platform, "Ending jump crossed through a platform: %s side=%s" % [platform_name, side])
	check(completions == count + 1, "Platform approach failed to finish level once")
	check(player.global_position.distance_to(arena.chamber.global_position + Vector2(-155,-1)) < 1.0, "Jump approach failed to reach chamber")
	print("CAD platform approach: clear jump, ground landing, then walk; platform=%s side=%s" % [platform_name, side])

func crouched_ending() -> void:
	await fresh()
	Input.action_press(&"crouch")
	await frames(4)
	check(player.states.current_name == &"Crouch", "Crouch ending fixture did not crouch")
	boss.health.kill(player)
	await wait_stage(arena.Stage.EXIT_WALK)
	check(player.states.current_name == &"Idle" and not player.is_crouched(), "Ending retained the crouched gameplay state")
	var unwanted_clips := [0]
	player.sprite.animation_changed.connect(func():
		if player.sprite.animation in [&"crouch", &"crouch_walk"]:
			unwanted_clips[0] += 1
	)
	var saw_run_frames := false
	for i in 800:
		await frames(1)
		if player.sprite.animation == &"run" and player.sprite.frame > 0:
			saw_run_frames = true
		if arena.stage == arena.Stage.COMPLETE:
			break
	Input.action_release(&"crouch")
	check(unwanted_clips[0] == 0 and saw_run_frames, "Crouch kept restarting the ending walk animation")
	check(arena.stage == arena.Stage.COMPLETE, "Crouched ending failed to complete")
	print("CAD crouched ending: standing handoff, advancing walk frames, completed")

func _ready() -> void:
	EventBus.level_completed.connect(func(_id: StringName): completions += 1)
	await direct_entry()
	await chamber_idle()
	await drop_and_walk()
	await drop_and_walk(true)
	await drop_and_walk(true, true)
	for platform_name in ["StepOne", "StepTwo", "StepThree"]:
		for side in [-1.0, 0.0, 1.0]:
			await jump_down_and_walk(platform_name, side)
	await crouched_ending()
	print("CAD_SEQUENCE_VERIFIED failures=%d" % failures)
	TimeService.reset()
	level.queue_free()
	await frames(2)
	get_tree().quit(1 if failures else 0)
