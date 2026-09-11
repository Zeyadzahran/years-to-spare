extends Node
## Focused contract test for the five player-targeted, vertical stomp patterns.

const LEVEL_SCENE := preload("res://src/levels/level_01/level_01.tscn")


func _ready() -> void:
	GameState.clear_run_progress()
	var level := LEVEL_SCENE.instantiate() as Level
	add_child(level)
	await get_tree().process_frame
	await get_tree().physics_frame

	var arena := level.get_node(^"World/BossArena") as BossArena
	var player := level.get_node(^"Entities/Player") as Player
	var spawn := arena.get_node(^"PlayerSpawn") as Marker2D
	player.global_position = spawn.global_position
	player.velocity = Vector2.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(arena.player == player)
	assert(arena.boss.has_node(^"StepAudio"))
	assert(arena.boss.has_node(^"WindupAudio"))
	assert(arena.boss.has_node(^"StompAudio"))
	assert(arena.boss.has_node(^"StompBodyAudio"))
	assert(arena.boss.has_node(^"HurtAudio"))
	assert(arena.boss.has_node(^"DeathAudio"))
	assert(StoneTitan.STEP_SOUNDS.size() == 5)
	assert(StoneTitan.WINDUP_SOUNDS.size() == 3)
	assert(StoneTitan.STOMP_SOUNDS.size() == 5)
	assert(StoneTitan.VOICE_GROWLS.size() == 3)
	assert(StoneTitan.VOICE_SHOUTS.size() == 3)
	assert(StoneTitan.VOICE_HURTS.size() == 4)
	assert(StoneTitan.VOICE_ROARS.size() == 2)
	assert(BossRock.LIGHT_IMPACTS.size() == 5)

	# Keep this test about stones only; normal reinforcement timing is covered by
	# verify_boss_encounter.gd.
	arena.set("_reinforcement_wave", BossArena.MAX_REINFORCEMENT_WAVES)
	arena.boss.process_mode = Node.PROCESS_MODE_DISABLED

	var seen_sizes := {}
	var seen_movements := {}
	var signatures := {}
	# Include both wall-side zones so the direct marker cannot silently clamp
	# toward the middle and miss a player sheltering at an edge.
	var player_positions := [2550.0, 3520.0, 4050.0, 4750.0, 3750.0]
	for stomp_number in range(1, 6):
		player.global_position = arena.to_global(Vector2(
			player_positions[stomp_number - 1], BossArena.FLOOR_Y))
		var expected_target_x := player.global_position.x
		arena._on_stomp_warning(stomp_number, 3)
		await get_tree().process_frame

		var rocks: Array[BossRock] = []
		for hazard in arena.hazards.get_children():
			if hazard is BossRock:
				rocks.append(hazard)
		assert(rocks.size() >= 3 and rocks.size() <= 4)
		assert(absf(rocks[0].landing_position.x - expected_target_x) < 1.0)

		# The marker predicts the boy briefly, then visibly locks before impact.
		player.velocity.x = 300.0
		player.global_position.x += 45.0
		await get_tree().create_timer(0.12).timeout
		assert(absf(rocks[0].landing_position.x - expected_target_x) >= 30.0)
		await get_tree().create_timer(0.3).timeout
		assert(rocks[0].warning_is_locked())
		var locked_x := rocks[0].landing_position.x
		player.global_position.x -= 170.0
		player.velocity.x = -300.0
		await get_tree().create_timer(0.08).timeout
		assert(is_equal_approx(rocks[0].landing_position.x, locked_x))

		var signature := ""
		for rock in rocks:
			var impact_audio := rock.get_node(^"ImpactAudio") as AudioStreamPlayer2D
			assert(impact_audio.stream.resource_path == "res://src/levels/level_01/audio/rock-sound.mp3")
			assert(rock.warning_active)
			assert(rock.is_vertical_plan())
			assert(absf(rock.landing_position.x - rocks[0].landing_position.x) <= 400.0)
			seen_sizes[rock.size_kind] = true
			seen_movements[rock.motion_kind] = true
			signature += "%d:%d," % [rock.size_kind, rock.motion_kind]
		signatures[signature] = true

		arena._on_stomp_impact(stomp_number, 3)
		await get_tree().process_frame
		assert(rocks[0].monitoring)
		assert(is_zero_approx((rocks[0].get("_velocity") as Vector2).x))
		var waves: Array[BossShockwave] = []
		for hazard in arena.hazards.get_children():
			if hazard is BossShockwave:
				waves.append(hazard)
		assert(waves.size() == 2)
		var frozen_x := waves[0].global_position.x
		TimeService.mode = TimeService.Mode.STOPPED
		await get_tree().create_timer(0.08).timeout
		assert(is_equal_approx(waves[0].global_position.x, frozen_x))
		if stomp_number == 5:
			# A stopped wave is safe to stand in, like the saw; it hurts again
			# the moment the clock restarts, even without moving.
			var health_before_wave := player.health.current
			player.global_position = Vector2(waves[0].global_position.x, player.global_position.y)
			player.velocity = Vector2.ZERO
			await get_tree().physics_frame
			await get_tree().physics_frame
			await get_tree().physics_frame
			assert(is_equal_approx(player.health.current, health_before_wave))
			TimeService.mode = TimeService.Mode.NORMAL
			await get_tree().physics_frame
			await get_tree().physics_frame
			assert(player.health.current < health_before_wave)
			player.health.heal(health_before_wave - player.health.current)
			player.global_position = arena.to_global(Vector2(
				player_positions[stomp_number - 1], BossArena.FLOOR_Y))
		TimeService.mode = TimeService.Mode.NORMAL
		await get_tree().create_timer(0.08).timeout
		assert(absf(waves[0].global_position.x - frozen_x) > 20.0)
		var has_visual_impact := false
		var has_debris := false
		for hazard in arena.hazards.get_children():
			if hazard is BossImpactEffect:
				has_visual_impact = true
				for part in hazard.get_children():
					if part is CPUParticles2D and part.texture is AtlasTexture:
						has_debris = true
		assert(has_visual_impact)
		assert(has_debris)

		arena._stop_all_danger()
		await get_tree().process_frame
		await get_tree().process_frame
		assert(arena.hazards.get_child_count() == 0)
		player.velocity = Vector2.ZERO

	assert(seen_sizes.has(BossRock.RockSize.SMALL))
	assert(seen_sizes.has(BossRock.RockSize.MEDIUM))
	assert(seen_sizes.has(BossRock.RockSize.LARGE))
	assert(seen_movements.has(BossRock.MotionKind.FALL))
	assert(seen_movements.has(BossRock.MotionKind.ERUPT))
	assert(signatures.size() == 5)

	# Normal hits work, but the cyan recovery window strongly rewards attacking
	# during a stopped-time opening.
	var health_before := arena.boss.health.current
	arena.boss.receive_player_hit(34.0, player)
	var normal_damage := health_before - arena.boss.health.current
	arena.boss.health.heal(normal_damage)
	arena.boss._set_vulnerable(true)
	health_before = arena.boss.health.current
	arena.boss.receive_player_hit(34.0, player)
	var vulnerable_damage := health_before - arena.boss.health.current
	assert(vulnerable_damage > normal_damage * 2.0)
	arena.boss._set_vulnerable(false)

	level.free()
	GameState.clear_run_progress()
	print("BOSS_STONES_VERIFIED")
	get_tree().quit()
