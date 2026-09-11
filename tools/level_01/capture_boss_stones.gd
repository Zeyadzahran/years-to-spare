extends Node
## Visual QA helper for player-targeted warnings and vertical rock motion.

const LEVEL_SCENE := preload("res://src/levels/level_01/level_01.tscn")
const OUTPUT_DIR := "/tmp/years-to-spare-boss-stones-qa"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var level := LEVEL_SCENE.instantiate() as Level
	add_child(level)
	await get_tree().process_frame
	await get_tree().physics_frame

	var arena := level.get_node(^"World/BossArena") as BossArena
	var player := level.get_node(^"Entities/Player") as Player
	var camera := player.get_node(^"Camera2D") as Camera2D
	player.global_position = arena.to_global(Vector2(3650.0, BossArena.FLOOR_Y))
	player.velocity = Vector2.ZERO
	arena.player = player
	arena.set("_reinforcement_wave", BossArena.MAX_REINFORCEMENT_WAVES)
	arena.boss.process_mode = Node.PROCESS_MODE_DISABLED
	player.process_mode = Node.PROCESS_MODE_DISABLED
	camera.limit_left = roundi(arena.global_position.x + BossArena.ROOM_LEFT)
	camera.limit_right = roundi(arena.global_position.x + BossArena.ROOM_RIGHT)
	camera.limit_top = roundi(arena.global_position.y + BossArena.ROOM_TOP)
	camera.limit_bottom = roundi(arena.global_position.y + BossArena.ROOM_BOTTOM)
	camera.position_smoothing_enabled = false
	camera.zoom = Vector2(0.86, 0.86)

	arena._on_stomp_warning(1, 3)
	await _capture(OUTPUT_DIR + "/fall_warning.png")
	arena._on_stomp_impact(1, 3)
	await get_tree().create_timer(0.28).timeout
	await _capture(OUTPUT_DIR + "/fall_vertical.png")
	arena._stop_all_danger()
	await get_tree().process_frame

	arena._on_stomp_warning(2, 3)
	await _capture(OUTPUT_DIR + "/eruption_warning.png")
	arena._on_stomp_impact(2, 3)
	await get_tree().create_timer(0.18).timeout
	await _capture(OUTPUT_DIR + "/eruption_vertical.png")
	arena._stop_all_danger()

	print("BOSS_STONE_CAPTURES=" + OUTPUT_DIR)
	get_tree().quit()


func _capture(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	assert(error == OK)
