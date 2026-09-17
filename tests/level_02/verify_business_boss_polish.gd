extends "res://tests/level_02/verify_business_boss.gd"
## Exact shot/pose timing, committed aim, counter windows, UI, and VFX history.

var shots: Array[BusinessLaser] = []
var shot_poses: Array = []

func record_shot(laser: BusinessLaser) -> void:
	shots.append(laser)
	shot_poses.append([boss.sprite.animation, boss.sprite.frame])
	check(laser.global_position.distance_to(boss.global_position + Vector2(boss.facing * BusinessBoss.BOSS_MUZZLE_FORWARD, BusinessBoss.BOSS_MUZZLE_HEIGHT)) < 0.1, "Laser did not start at muzzle")

func prepare_pattern(number: int) -> void:
	await fresh(false)
	shots.clear()
	shot_poses.clear()
	player.global_position = boss.global_position + Vector2(-400, 0)
	arena.prepare_gate_entry(player)
	boss.set_combat_phase(number)
	boss.target = player
	boss.shot_fired.connect(record_shot)
	boss._change_state(&"Attack")

func wait_recovery() -> void:
	for i in 180:
		if boss.state == &"Recover":
			return
		await frames(1)
	check(false, "Pattern never reached recovery")

func patterns() -> void:
	for number in [1, 2, 3]:
		await prepare_pattern(number)
		await frames(24)
		check(shots.is_empty() and boss.sprite.animation == &"charge", "Missing anticipation before first shot")
		check(boss.sprite.material == null and boss.sprite.scale == Vector2.ONE * BusinessBoss.COMBAT_ART_SCALE and boss.sprite.rotation == 0.0, "Boss rendering was distorted")
		check(boss.sprite.sprite_frames.get_frame_texture(&"fire", 0) is AtlasTexture, "Refined shooting frames missing")
		var held_frame := boss.sprite.frame
		TimeService.mode = TimeService.Mode.STOPPED
		await frames(40)
		check(boss.sprite.frame == held_frame and shots.is_empty(), "Charge moved or fired during Stop Time")
		check(boss.charge_audio.stream_paused, "Charge sound ignored Stop Time")
		TimeService.mode = TimeService.Mode.NORMAL
		# The player crosses behind after the warning starts; the burst must
		# finish on the originally advertised side rather than snap around.
		player.global_position = boss.global_position + Vector2(400, 0)
		await wait_recovery()
		var expected: int = [1, 3, 2][number - 1]
		check(shots.size() == expected, "Phase %d emitted %d shots, expected %d" % [number, shots.size(), expected])
		for shot in shots:
			check(is_instance_valid(shot) and shot._velocity.x < 0.0, "Burst reversed its aim mid-attack")
		for pose in shot_poses:
			check(pose == [&"fire", 0], "Muzzle flash did not coincide with laser emission")
		await frames(6)
		check(boss.sprite.animation == &"recover", "Missing weapon-lowering recovery pose")
		check(arena.get_node("BossUI/Panel/Status").text == "COUNTERATTACK", "Recovery UI missing")
		boss.receive_player_hit(34.0, player)
		check(boss.state == &"Recover", "Hit shortened recovery by replacing it with Hurt")
		await frames(30)
		check(boss.state == &"Recover" and shots.size() == expected, "Counterattack window ended early")
		if number == 3:
			for i in 100:
				if boss.phase == BusinessBoss.Phase.DISAPPEARING:
					break
				await frames(1)
			check(boss.phase == BusinessBoss.Phase.DISAPPEARING, "Final phase did not reposition after the burst")
			check(boss._arrival_position().distance_to(player.global_position) >= 180.0, "Combo teleport landed on player")
			var previous_shots := shots.size()
			await frames(60)
			check(shots.size() == previous_shots, "Combo fired before arrival and its warning completed")
	print("BOSS_POLISH patterns: single/triple/double, warning, flash timing, locked aim, recovery, combo")

func burst_rewind() -> void:
	await prepare_pattern(2)
	for i in 90:
		if shots.size() == 1: break
		await frames(1)
	await frames(5)
	TimeService.mode = TimeService.Mode.REWINDING
	await frames(6)
	TimeService.mode = TimeService.Mode.NORMAL
	check(boss.state == &"Attack" and boss._shots_fired == 0, "Rewind did not restore charge before the burst")
	check(boss.sprite.animation == &"charge", "Rewind restored wrong combat pose")
	await frames(1)
	check(get_tree().get_nodes_in_group(&"business_laser").is_empty(), "Abandoned shot survived rewind")
	shots.clear()
	shot_poses.clear()
	await wait_recovery()
	check(shots.size() == 3 and boss.combat_phase == 2, "Rewound burst duplicated or skipped a shot")
	print("BOSS_POLISH burst rewind: charge restored, abandoned laser removed, three shots replayed")

func laser_effects() -> void:
	await fresh(false)
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2, 180)
	shape.shape = rectangle
	wall.add_child(shape)
	wall.position = Vector2(18100, 500)
	level.add_child(wall)
	await frames(3)
	var laser := preload("res://src/actors/enemy/business_laser.tscn").instantiate() as BusinessLaser
	add_child(laser)
	laser.global_position = Vector2(18000, 500)
	laser.setup(Vector2(720, 0), 18.0, boss)
	await frames(12)
	check(laser._spent and laser.visible and not laser.get_node("Sprite").visible, "Wall hit did not show impact instead of flying sprite")
	check(laser.global_position.x < 18100.0, "Laser tunneled through thin wall")
	TimeService.mode = TimeService.Mode.STOPPED
	var impact_age := laser._impact_age
	await frames(30)
	check(laser._impact_age == impact_age, "Impact effect continued during Stop Time")
	TimeService.mode = TimeService.Mode.NORMAL
	# Rewind only the stopped interval first, then the impact itself.
	await rewind_ticks(16)
	check(is_instance_valid(laser) and not laser._spent and laser.visible, "Rewind failed to restore the flying laser")
	await frames(50)
	check(not laser.visible, "Impact did not retire after playback resumed")
	print("BOSS_POLISH laser: swept wall hit, visible impact, frozen effect, impact rewind, retirement")

func feedback() -> void:
	await fresh()
	check(arena.get_node("BossUI/Panel/BossHealth/FirstThird").anchor_left > 0.33, "Health phase marks missing")
	boss.receive_player_hit(450.0, player)
	await wait_stage(arena.Stage.SPAWNING)
	await frames(1)
	check(arena.reinforcement_gate.is_visible_in_tree(), "Portal hidden while spawning reinforcements")
	var status: Label = arena.get_node("BossUI/Panel/Status")
	check(status.text == "REINFORCEMENTS REMAINING: %d" % arena._wave_count, "Pending reinforcements missing from UI")
	await wait_stage(arena.Stage.WAVE)
	await frames(40)
	arena._reinforcements[0].health.kill(player)
	await frames(2)
	check(status.text == "REINFORCEMENTS REMAINING: %d" % (arena._wave_count - 1), "Reinforcement UI did not count a kill")
	clear_wave()
	await wait_stage(arena.Stage.RETURNING)
	for i in 120:
		if boss.phase == BusinessBoss.Phase.RECOVERING: break
		await frames(1)
	await frames(2)
	check(boss._arrival_fx_left > 0.0, "Arrival has no burst effect")
	var camera: Camera2D = player.get_node("Camera2D")
	check(camera.offset.length() > 0.0 and camera.offset.length() < 10.0, "Arrival shake missing or excessive")
	await frames(30)
	check(camera.offset == Vector2.ZERO, "Arrival shake failed to settle")
	print("BOSS_POLISH feedback: phase boundaries, pending/live wave count, arrival burst and brief shake")

func hurt_animation() -> void:
	await prepare_pattern(1)
	boss._change_state(&"Recover")
	boss.receive_player_hit(14.0, player)
	check(boss.sprite.animation == &"hurt" and boss.sprite.frame == 0, "Hit did not start hurt pose")
	await frames(6)
	check(boss.sprite.frame > 0, "Hurt animation stayed on a single pose")
	var saved := boss.rewind_capture()
	var held := boss.sprite.frame
	TimeService.mode = TimeService.Mode.STOPPED
	await frames(20)
	check(boss.sprite.frame == held, "Hurt animation ignored Stop Time")
	TimeService.mode = TimeService.Mode.NORMAL
	await frames(15)
	check(boss.sprite.animation == &"recover", "Hurt animation failed to return to recovery")
	boss.rewind_apply(saved)
	check(boss.sprite.animation == &"hurt" and boss.sprite.frame == held, "Rewind did not restore hurt pose")
	print("BOSS_POLISH hurt: multiple poses, Stop Time, recovery, saved-pose restoration")

func teleport_animation() -> void:
	await fresh()
	boss.begin_intermission()
	check(boss.sprite.animation == &"teleport" and boss.sprite.frame == 0, "Disappearance did not start its own animation")
	await frames(16)
	var held := boss.sprite.frame
	check(held >= 2 and held <= 4 and boss.sprite.self_modulate.a == 1.0, "Disappearance faded before its body-breakup frames")
	var saved := boss.rewind_capture()
	TimeService.mode = TimeService.Mode.STOPPED
	await frames(30)
	check(boss.sprite.frame == held, "Disappearance poses advanced during Stop Time")
	TimeService.mode = TimeService.Mode.NORMAL
	await frames(10)
	check(boss.sprite.frame > held, "Disappearance remained a single pose")
	boss.rewind_apply(saved)
	check(boss.sprite.animation == &"teleport" and boss.sprite.frame == held, "Rewind failed to restore the disappearance pose")
	var seen: Array[int] = []
	for i in 45:
		if boss.phase == BusinessBoss.Phase.WAITING:
			break
		if not seen.has(boss.sprite.frame):
			seen.append(boss.sprite.frame)
		await frames(1)
	check(seen.has(7) and not boss.sprite.visible, "Disappearance skipped its final sparks or left the boss visible")
	boss.resume_after_intermission(arena.to_global(Vector2(1100,639)))
	check(boss.sprite.animation == &"teleport" and boss.sprite.frame == 7, "Arrival did not start with the final disappearance pose")
	await frames(20)
	check(boss.sprite.frame < 7 and boss.sprite.frame > 0, "Arrival did not reassemble the boss")
	await frames(30)
	check(boss.phase == BusinessBoss.Phase.RECOVERING and boss.sprite.visible, "Arrival failed to restore the solid boss")
	print("BOSS_POLISH teleport: distinct dissolve poses, frozen pose, restored pose, final sparks, reverse arrival")

func idle_and_defeat_animation() -> void:
	await fresh(false)
	var held := boss.sprite.frame
	await frames(13)
	check(boss.sprite.animation == &"idle" and boss.sprite.frame != held, "Idle stayed on one pose")
	var saved := boss.rewind_capture()
	held = boss.sprite.frame
	TimeService.mode = TimeService.Mode.STOPPED
	await frames(20)
	check(boss.sprite.frame == held, "Idle ignored Stop Time")
	TimeService.mode = TimeService.Mode.NORMAL
	await frames(13)
	boss.rewind_apply(saved)
	check(boss.sprite.frame == held, "Rewind did not restore idle pose")
	boss.health.kill(player)
	check(boss.sprite.animation == &"dying" and boss.sprite.frame == 0, "Defeat did not start its collapse animation")
	await frames(12)
	held = boss.sprite.frame
	saved = boss.rewind_capture()
	check(held > 0, "Defeat stayed on one pose")
	TimeService.mode = TimeService.Mode.STOPPED
	await frames(20)
	check(boss.sprite.frame == held, "Defeat ignored Stop Time")
	TimeService.mode = TimeService.Mode.NORMAL
	await frames(12)
	boss.rewind_apply(saved)
	check(boss.sprite.animation == &"dying" and boss.sprite.frame == held, "Rewind did not restore defeat pose")
	print("BOSS_POLISH idle/defeat: animated poses, Stop Time, saved-pose restoration")

func _ready() -> void:
	await idle_and_defeat_animation()
	await patterns()
	await hurt_animation()
	await burst_rewind()
	await laser_effects()
	await feedback()
	await teleport_animation()
	print("BUSINESS_BOSS_POLISH_VERIFIED failures=%d" % failures)
	TimeService.reset()
	level.queue_free()
	await frames(2)
	get_tree().quit(1 if failures else 0)
