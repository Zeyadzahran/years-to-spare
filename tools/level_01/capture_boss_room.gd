extends Node
## Visual QA helper. Captures the live room before and after the staircase reveal.

const LEVEL_SCENE := preload("res://src/levels/level_01/level_01.tscn")
const OUTPUT_DIR := "/tmp/years-to-spare-boss-qa"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var level := LEVEL_SCENE.instantiate() as Level
	add_child(level)
	await get_tree().process_frame
	var arena := level.get_node(^"World/BossArena") as BossArena
	var player := level.get_node(^"Entities/Player") as Player
	var camera := player.get_node(^"Camera2D") as Camera2D
	player.global_position = arena.to_global(Vector2(3650, BossArena.FLOOR_Y))
	player.velocity = Vector2.ZERO
	player.process_mode = Node.PROCESS_MODE_DISABLED
	arena.boss.process_mode = Node.PROCESS_MODE_DISABLED
	camera.limit_left = roundi(arena.global_position.x + BossArena.ROOM_LEFT)
	camera.limit_right = roundi(arena.global_position.x + BossArena.ROOM_RIGHT)
	camera.limit_top = roundi(arena.global_position.y + BossArena.ROOM_TOP)
	camera.limit_bottom = roundi(arena.global_position.y + BossArena.ROOM_BOTTOM)
	camera.position_smoothing_enabled = false
	camera.zoom = Vector2(0.75, 0.75)
	player.global_position = arena.to_global(Vector2(3000, BossArena.FLOOR_Y))
	await _capture(OUTPUT_DIR + "/combat_left.png")
	player.global_position = arena.to_global(Vector2(3650, BossArena.FLOOR_Y))
	await _capture(OUTPUT_DIR + "/combat_center.png")
	player.global_position = arena.to_global(Vector2(4300, BossArena.FLOOR_Y))
	await _capture(OUTPUT_DIR + "/combat_right.png")

	await arena._reveal_staircase()
	await _capture(OUTPUT_DIR + "/victory_route.png")
	print("BOSS_ROOM_CAPTURES=" + OUTPUT_DIR)
	get_tree().quit()


func _capture(path: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	assert(error == OK)
