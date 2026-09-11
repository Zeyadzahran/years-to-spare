extends Node
## Runtime coverage for the inline boss arena and environmental respawn rules.

const LEVEL_SCENE := preload("res://src/levels/level_01/level_01.tscn")
const PLAYER_SCENE := preload("res://src/actors/player/player.tscn")
const LEVEL_START := Vector2(183, 618)
const TEST_CHECKPOINT := Vector2(9198, 604)
const SPIKE_SCENES := [
	preload("res://src/levels/level_01/hazards/spike_strip_small.tscn"),
	preload("res://src/levels/level_01/hazards/spike_strip_large.tscn"),
	preload("res://src/levels/level_01/hazards/wall_trap.tscn"),
	preload("res://src/levels/level_01/hazards/ceiling_obstacle.tscn"),
]

func _ready() -> void:
	GameState.clear_run_progress()
	_verify_editor_authored_boss_arena()
	await _verify_normal_damage_and_checkpoint()
	await _verify_hazard_deaths_respect_hearts_and_checkpoint()
	await _verify_inline_boss_arena()
	GameState.clear_run_progress()
	print("BOSS_GATE_AND_RESPAWN_RULES_VERIFIED")
	get_tree().quit()


func _verify_editor_authored_boss_arena() -> void:
	# Inspect before add_child(), so these nodes/cells can only have come from
	# level_01.tscn and are therefore visible in that editor scene too.
	var level := LEVEL_SCENE.instantiate()
	var arena := level.get_node(^"World/BossArena") as Node2D
	var terrain := level.get_node(^"World/SalvageYard/Terrain") as TileMapLayer
	var spawn := arena.get_node(^"PlayerSpawn") as Marker2D
	assert(arena.has_node(^"Atmosphere/DeepRecess"))
	assert(arena.has_node(^"Atmosphere/Dust"))
	assert(terrain.tile_set == load("res://src/levels/level_01/terrain_tileset.tres"))
	assert(arena.has_node(^"TrappedSister"))
	assert(arena.has_node(^"FutureBossPosition"))
	assert(arena.has_node(^"Guardian"))
	assert(arena.has_node(^"ArenaShell"))
	assert(arena.has_node(^"BackdropGuards/Left"))
	assert(arena.has_node(^"BackdropGuards/Right"))
	assert(arena.has_node(^"BackdropGuards/Top"))
	assert(arena.has_node(^"BackdropGuards/Bottom"))
	assert(not arena.has_node(^"Warden"))
	assert(level.find_children("Player", "Player", true, false).size() == 1)
	var below_spawn := terrain.local_to_map(
		terrain.to_local(arena.to_global(spawn.position + Vector2(0, 36)))
	)
	assert(terrain.get_cell_source_id(below_spawn) >= 0)
	level.free()


func _verify_inline_boss_arena() -> void:
	var level := await _fresh_level()
	var player := level.get_node(^"Entities/Player") as Player
	var gate := level.get_node(^"World/SalvageYard/Gates/BossGate") as BossGate
	var arena := level.get_node(^"World/BossArena") as Node2D
	var spawn := arena.get_node(^"PlayerSpawn") as Marker2D
	var boss_background := arena.get_node(^"BossBackground") as Sprite2D
	var terrain := level.get_node(^"World/SalvageYard/Terrain") as TileMapLayer
	assert(player != null)
	assert(gate != null)
	assert(gate.body_entered.is_connected(gate._on_body_entered))

	player.age.set_to(33.0)
	var health_before := player.health.current
	var player_id := player.get_instance_id()
	# Enter the real Area2D collision so the test covers automatic activation,
	# not a button press or a direct call to the transition implementation.
	var gate_shape := gate.get_node(^"Shape") as CollisionShape2D
	player.global_position = gate_shape.global_position + Vector2(0, 50)
	player.velocity = Vector2.ZERO
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(gate.get("_transitioning"))
	assert(player.process_mode == Node.PROCESS_MODE_DISABLED)
	assert(gate.get_node(^"Effects").emitting)

	# Feedback and fade happen before crossing into the arena.
	await get_tree().create_timer(0.43).timeout
	assert(gate.get_node(^"Glow").modulate.a > 0.0)
	assert(gate.get_node(^"Transition/Fade").color.a > 0.0)

	# The same Player crosses within Level 1 only while the screen is fully
	# covered. Camera limits and the boss backdrop must be ready before reveal.
	await get_tree().create_timer(0.25).timeout
	assert(player.get_instance_id() == player_id)
	assert(level.has_node(^"World/BossArena"))
	assert(arena.has_node(^"TrappedSister"))
	assert((arena.get_node(^"TrappedSister") as AnimatedSprite2D).is_visible_in_tree())
	assert(not arena.has_node(^"Warden"))
	assert(get_tree().get_nodes_in_group(&"player").size() == 1)
	assert(player.global_position.distance_to(spawn.global_position) < 4.0)
	assert(player.process_mode == Node.PROCESS_MODE_DISABLED)
	assert((gate.get_node(^"Transition/Fade") as ColorRect).color.a >= 0.999)
	assert(boss_background.is_visible_in_tree())
	var camera := player.get_node(^"Camera2D") as Camera2D
	assert(not camera.position_smoothing_enabled)
	assert(not camera.limit_smoothed)
	assert(camera.limit_left == roundi(arena.global_position.x + BossArena.ROOM_LEFT))
	assert(camera.limit_right == roundi(arena.global_position.x + BossArena.ROOM_RIGHT))
	_assert_no_desert_left_of_boss_background(camera, boss_background)

	await get_tree().create_timer(0.7).timeout
	print("BOSS_GATE_POSITION actual=%s spawn=%s" % [player.global_position, spawn.global_position])
	assert(player.global_position.distance_to(spawn.global_position) < 4.0)
	assert(player.is_on_floor())
	assert(player.facing == 1)
	assert(is_equal_approx(player.age.age, 33.0))
	assert(is_equal_approx(player.health.current, health_before))
	assert(player.process_mode == Node.PROCESS_MODE_INHERIT)
	assert(is_zero_approx((gate.get_node(^"Transition/Fade") as ColorRect).color.a))
	assert(terrain.tile_set == load("res://src/levels/level_01/terrain_tileset.tres"))
	assert((player.get_node(^"Camera2D") as Camera2D).zoom == BossGate.ARENA_CAMERA_ZOOM)
	assert(camera.enabled)
	assert(camera.get_parent() == player)
	assert(get_viewport().get_visible_rect().size.x / camera.zoom.x >= 1560.0)

	# Restoring the process mode is not enough on its own: prove normal input
	# moves the player as soon as the room has been revealed.
	var control_start_x := player.global_position.x
	Input.action_press(&"move_right")
	for frame in 12:
		await get_tree().physics_frame
	Input.action_release(&"move_right")
	assert(player.global_position.x > control_start_x + 1.0)

	# A second call cannot restart the fade or move the Player again.
	player.velocity = Vector2.ZERO
	var arena_position := player.global_position
	gate._on_body_entered(player)
	await get_tree().create_timer(0.1).timeout
	assert(absf(player.global_position.x - arena_position.x) < 1.0)
	assert(is_zero_approx((gate.get_node(^"Transition/Fade") as ColorRect).color.a))
	assert(get_tree().get_nodes_in_group(&"player").size() == 1)
	assert(player.process_mode == Node.PROCESS_MODE_INHERIT)
	assert(not gate.monitoring)
	level.free()
	await get_tree().process_frame


func _assert_no_desert_left_of_boss_background(
		camera: Camera2D, background: Sprite2D) -> void:
	var background_width := background.region_rect.size.x * absf(background.global_scale.x)
	var background_left := background.global_position.x - background_width * 0.5
	var visible_width := get_viewport().get_visible_rect().size.x / camera.zoom.x
	var camera_left := camera.get_screen_center_position().x - visible_width * 0.5
	print("BOSS_REVEAL_LEFT camera=%s background=%s" % [camera_left, background_left])
	assert(camera_left >= background_left - 1.0)


func _verify_normal_damage_and_checkpoint() -> void:
	var player := await _fresh_player()
	var source := Node2D.new()
	add_child(source)
	var health_before := player.health.current
	player.health.take_damage(34.0, source)
	assert(player.health.is_alive())
	assert(is_equal_approx(player.health.current, health_before - 34.0))
	assert(player.states.current_name == &"Hurt")
	player.free()
	source.free()
	await get_tree().process_frame

	GameState.set_checkpoint(&"normal_damage_checkpoint", TEST_CHECKPOINT, 27.0)
	var level := await _fresh_level()
	var respawned := level.get_node(^"Entities/Player") as Player
	print("NORMAL_RESPAWN actual=%s checkpoint=%s" % [respawned.global_position, TEST_CHECKPOINT])
	assert(respawned.global_position.distance_to(TEST_CHECKPOINT) < 5.0)
	level.free()
	await get_tree().process_frame


## Every spike variant and the void kill through the same Player.die_instantly
## path, so proving the cascade once here covers all of them: a mistake costs
## a heart and sends the boy back to his checkpoint, not the level, and only
## running out of hearts costs the checkpoint and restarts the level itself.
func _verify_hazard_deaths_respect_hearts_and_checkpoint() -> void:
	for packed_spike: PackedScene in SPIKE_SCENES:
		var player := await _fresh_player()
		var spike := packed_spike.instantiate() as Hazard
		add_child(spike)
		await get_tree().process_frame
		assert(spike.instant_death)
		spike._hurt(player)
		assert(not player.health.is_alive())
		assert(player.states.current_name == &"Dead")
		player.free()
		spike.free()
		await get_tree().process_frame

	var void_player := await _fresh_player()
	void_player.global_position.y = Player.VOID_DEATH_Y + 1.0
	await get_tree().physics_frame
	assert(not void_player.health.is_alive())
	assert(void_player.states.current_name == &"Dead")
	void_player.free()
	await get_tree().process_frame

	# The above proves every hazard kills instantly through the shared path;
	# from here the cascade is GameState's own, the same one
	# Level._on_player_died drives on every real reload.
	GameState.clear_run_progress()
	GameState.set_checkpoint(&"heart_test_checkpoint", TEST_CHECKPOINT, 24.0)

	# A) 3 hearts -> 2: the checkpoint still covers it.
	assert(GameState.hearts == 3)
	assert(GameState.lose_heart() == 2)
	assert(GameState.has_checkpoint(&"phase_1"))
	assert(GameState.checkpoint_position == TEST_CHECKPOINT)
	var level_a := LEVEL_SCENE.instantiate() as Level
	add_child(level_a)
	var respawned_a := level_a.get_node(^"Entities/Player") as Player
	print("HEART_RESPAWN_2 actual=%s checkpoint=%s" % [respawned_a.global_position, TEST_CHECKPOINT])
	assert(respawned_a.global_position.distance_to(TEST_CHECKPOINT) < 5.0)
	level_a.free()
	await get_tree().process_frame

	# B) 2 hearts -> 1: same checkpoint, still not cleared.
	assert(GameState.lose_heart() == 1)
	assert(GameState.has_checkpoint(&"phase_1"))
	assert(GameState.checkpoint_position == TEST_CHECKPOINT)
	var level_b := LEVEL_SCENE.instantiate() as Level
	add_child(level_b)
	var respawned_b := level_b.get_node(^"Entities/Player") as Player
	print("HEART_RESPAWN_1 actual=%s checkpoint=%s" % [respawned_b.global_position, TEST_CHECKPOINT])
	assert(respawned_b.global_position.distance_to(TEST_CHECKPOINT) < 5.0)
	level_b.free()
	await get_tree().process_frame

	# C) 1 heart -> 0: no heart left to cover it, so the run - checkpoint
	# included - starts over exactly like Level._on_player_died does.
	assert(GameState.lose_heart() == 0)
	GameState.clear_run_progress()
	assert(not GameState.has_checkpoint(&"phase_1"))
	# D) ...and the reset hands the next attempt its three hearts back.
	assert(GameState.hearts == 3)
	var level_c := LEVEL_SCENE.instantiate() as Level
	add_child(level_c)
	var respawned_c := level_c.get_node(^"Entities/Player") as Player
	print("FULL_RESTART_RESPAWN actual=%s start=%s" % [respawned_c.global_position, LEVEL_START])
	assert(respawned_c.global_position == LEVEL_START)
	for frame in 4:
		await get_tree().physics_frame
	assert(respawned_c.is_on_floor())
	level_c.free()
	await get_tree().process_frame
	GameState.clear_run_progress()


func _fresh_level() -> Level:
	var level := LEVEL_SCENE.instantiate() as Level
	add_child(level)
	await get_tree().process_frame
	await get_tree().physics_frame
	return level


func _fresh_player() -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	await get_tree().process_frame
	await get_tree().physics_frame
	return player
