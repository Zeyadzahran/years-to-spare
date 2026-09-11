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
	assert(not arena.boss.has_node(^"StompAudio"))

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

		var signature := ""
		for rock in rocks:
			assert(rock.warning_active)
			assert(rock.is_vertical_plan())
			assert(absf(rock.landing_position.x - expected_target_x) <= 400.0)
			seen_sizes[rock.size_kind] = true
			seen_movements[rock.motion_kind] = true
			signature += "%d:%d," % [rock.size_kind, rock.motion_kind]
		signatures[signature] = true

		arena._on_stomp_impact(stomp_number, 3)
		await get_tree().process_frame
		assert(rocks[0].monitoring)
		assert(is_zero_approx((rocks[0].get("_velocity") as Vector2).x))
		var has_visual_impact := false
		for hazard in arena.hazards.get_children():
			if hazard is BossImpactEffect:
				has_visual_impact = true
		assert(has_visual_impact)

		arena._stop_all_danger()
		await get_tree().process_frame
		await get_tree().process_frame
		assert(arena.hazards.get_child_count() == 0)

	assert(seen_sizes.has(BossRock.RockSize.SMALL))
	assert(seen_sizes.has(BossRock.RockSize.MEDIUM))
	assert(seen_sizes.has(BossRock.RockSize.LARGE))
	assert(seen_movements.has(BossRock.MotionKind.FALL))
	assert(seen_movements.has(BossRock.MotionKind.ERUPT))
	assert(signatures.size() == 5)

	level.free()
	GameState.clear_run_progress()
	print("BOSS_STONES_VERIFIED")
	get_tree().quit()
