extends Node
## Contract coverage for the resized, still-inline boss room and its encounter.

const LEVEL_SCENE := preload("res://src/levels/level_01/level_01.tscn")

var _completions := 0


func _ready() -> void:
	GameState.clear_run_progress()
	_verify_authored_room()
	await _verify_fight_and_outro()
	GameState.clear_run_progress()
	print("BOSS_ENCOUNTER_VERIFIED")
	get_tree().quit()


func _verify_authored_room() -> void:
	var level := LEVEL_SCENE.instantiate()
	var arena := level.get_node(^"World/BossArena") as BossArena
	var background := arena.get_node(^"BossBackground") as Sprite2D
	var shell := arena.get_node(^"ArenaShell") as TileMapLayer
	var sister := arena.get_node(^"TrappedSister") as Sprite2D
	var spawn := arena.get_node(^"PlayerSpawn") as Marker2D
	var titan := arena.get_node(^"StoneTitan") as StoneTitan
	assert(background.texture == load("res://assets/sprites/boss-background.png"))
	assert(background.region_enabled)
	assert(background.region_rect == Rect2(225, 0, 550, 375))
	assert(shell.tile_set == load("res://src/levels/level_01/terrain_tileset.tres"))
	assert(shell.get_used_cells().size() == 36)
	assert(spawn.position.x >= BossArena.ROOM_LEFT and spawn.position.x < titan.position.x)
	assert(sister.position.x > titan.position.x)
	assert(sister.position.y <= 0.0)
	var combat_platforms := [
		arena.get_node(^"BossPlatform") as StaticBody2D,
		arena.get_node(^"UpperPlatform") as StaticBody2D,
		arena.get_node(^"RightDodgePlatform") as StaticBody2D,
	]
	for platform in combat_platforms:
		var platform_size: Vector2 = platform.get("size")
		assert(platform_size.x >= 180.0 and platform_size.x <= 240.0)
		assert(platform_size.y <= 18.0)
	var sister_platform := arena.get_node(^"SisterArea/SisterPlatform") as StaticBody2D
	var sister_platform_size: Vector2 = sister_platform.get("size")
	assert(sister_platform_size.x >= 260.0 and sister_platform_size.x <= 320.0)
	assert(sister_platform.position.y == sister.position.y)
	var staircase := arena.get_node(^"SisterArea/Staircase") as Node2D
	assert(not staircase.visible)
	assert(staircase.get_child_count() == 2)
	var previous_position := Vector2(-INF, INF)
	for step in staircase.get_children():
		assert(step is StaticBody2D)
		assert(step.get("width") == 200.0)
		assert(step.position.x > previous_position.x)
		assert(step.position.y < previous_position.y)
		previous_position = step.position
	assert(not arena.has_node(^"SisterArea/ObjectiveSeal"))
	var titan_sprite := titan.get_node(^"Sprite") as AnimatedSprite2D
	var titan_shape := (titan.get_node(^"Shape") as CollisionShape2D).shape as CapsuleShape2D
	# The tallest opaque pose uses 45 pixels of the 64-pixel animation frame.
	var visual_height := 45.0 * titan_sprite.scale.y
	assert(visual_height >= 145.0 and visual_height <= 175.0)
	assert(titan_shape.height >= 145.0 and titan_shape.height <= 175.0)
	assert(titan_shape.radius * 2.0 <= 100.0)
	level.free()


func _verify_fight_and_outro() -> void:
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
	assert(arena.get("_started"))
	assert(arena.boss.active)
	var camera := player.get_node(^"Camera2D") as Camera2D
	assert(camera.limit_left == roundi(arena.global_position.x + BossArena.ROOM_LEFT))
	assert(camera.limit_right == roundi(arena.global_position.x + BossArena.ROOM_RIGHT))
	assert(BossArena.ROOM_RIGHT - BossArena.BOSS_RIGHT <= 160.0)

	# The old 4020 boundary stranded the boss before the room's right-side combat
	# floor. Put both actors beyond it and confirm the boss can keep pursuing.
	arena.boss.global_position = arena.to_global(Vector2(4200, BossArena.FLOOR_Y))
	arena.boss.set("_attack_cooldown", 99.0)
	player.global_position = arena.to_global(Vector2(4550, BossArena.FLOOR_Y))
	await get_tree().create_timer(0.5).timeout
	assert(arena.to_local(arena.boss.global_position).x > 4240.0)

	arena.boss._begin_stomp()
	await get_tree().process_frame
	assert(arena.hazards.get_child_count() >= 3)
	for hazard in arena.hazards.get_children():
		if hazard is BossRock:
			assert(not hazard.monitoring)
	await get_tree().create_timer(1.15).timeout
	var launched := false
	for hazard in arena.hazards.get_children():
		if hazard is BossRock and hazard.monitoring:
			launched = true
	assert(launched)

	arena._on_stomp_warning(3, 1)
	await get_tree().process_frame
	assert(arena.arena_adds.get_child_count() == 1)
	var guard := arena.arena_adds.get_child(0) as Guard
	assert(guard != null)
	# A physics tick may have begun the patrol before this check; its recorded
	# home must still be at the spawn, not thousands of pixels outside the room.
	assert(absf(guard.patrol_origin_x - guard.global_position.x) < 10.0)
	player.global_position = guard.global_position + Vector2(-180.0, 0.0)
	var distance_before_chase := absf(guard.global_position.x - player.global_position.x)
	await get_tree().create_timer(0.3).timeout
	assert(guard.state == &"Chase" or guard.state == &"Attack")
	assert(absf(guard.global_position.x - player.global_position.x) < distance_before_chase)
	player.global_position = arena.to_global(Vector2(3900, BossArena.FLOOR_Y))
	player.begin_swing()
	assert(player.has_combat_effects())
	EventBus.level_completed.connect(_on_level_completed)
	arena.boss.health.kill(player)
	await get_tree().process_frame
	assert(arena.hazards.get_child_count() == 0)
	assert(arena.arena_adds.get_child_count() == 0)
	assert(arena.staircase.visible)
	assert(player.process_mode != Node.PROCESS_MODE_DISABLED)
	await get_tree().create_timer(0.65).timeout
	assert(player.process_mode == Node.PROCESS_MODE_DISABLED)
	assert(not player.has_combat_effects())
	assert(camera.process_mode == Node.PROCESS_MODE_ALWAYS)
	for step in arena.staircase.get_children():
		assert(step.collision_layer == 1)
		assert(step.modulate.a > 0.99)
	var player_x_before_follow := player.global_position.x
	var camera_x_before_follow := camera.get_screen_center_position().x
	await get_tree().create_timer(0.65).timeout
	assert(player.global_position.x > player_x_before_follow + 40.0)
	assert(camera.get_screen_center_position().x > camera_x_before_follow + 20.0)
	await get_tree().create_timer(4.1).timeout
	assert((arena.fade as ColorRect).color.a > 0.98)
	await get_tree().process_frame
	assert(_completions == 1)
	EventBus.level_completed.disconnect(_on_level_completed)
	level.free()
	await get_tree().process_frame


func _on_level_completed(_level_id: StringName) -> void:
	_completions += 1
