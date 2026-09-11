extends Node
## Visual QA helper for the boss fight's presentation: the wake-up, the stomp
## wind-up and slam, the open window, the stones' warnings and flight, and the
## crumbling death. Needs a real renderer for the shaders; see capture_level.py
## for the flags.

const LEVEL_SCENE := preload("res://src/levels/level_01/level_01.tscn")
const OUTPUT_DIR := "/tmp/years-to-spare-boss-stones-qa"

var _arena: BossArena
var _player: Player


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var level := LEVEL_SCENE.instantiate() as Level
	add_child(level)
	await get_tree().process_frame
	await get_tree().physics_frame

	_arena = level.get_node(^"World/BossArena") as BossArena
	_player = level.get_node(^"Entities/Player") as Player
	var camera := _player.get_node(^"Camera2D") as Camera2D
	var spawn := _arena.get_node(^"PlayerSpawn") as Marker2D
	# The gate would normally do this on the way in.
	camera.zoom = BossGate.ARENA_CAMERA_ZOOM
	camera.position_smoothing_enabled = false
	_player.global_position = spawn.global_position
	_player.velocity = Vector2.ZERO
	_arena.set("_reinforcement_wave", BossArena.MAX_REINFORCEMENT_WAVES)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(_arena.get("_started"))
	camera.reset_smoothing()

	# The wake-up, a beat into the roar.
	await get_tree().create_timer(0.7).timeout
	await _capture("01_awaken.png")
	await _arena.boss.awakened
	_arena.boss.process_mode = Node.PROCESS_MODE_DISABLED
	_player.process_mode = Node.PROCESS_MODE_DISABLED
	_player.global_position = _arena.to_global(Vector2(3220.0, BossArena.FLOOR_Y))
	_player.velocity = Vector2.ZERO
	_arena.boss.global_position = _arena.to_global(Vector2(3900.0, BossArena.FLOOR_Y))
	_arena.boss.velocity = Vector2.ZERO
	camera.position_smoothing_enabled = false
	camera.reset_smoothing()
	_arena.boss.process_mode = Node.PROCESS_MODE_INHERIT
	await get_tree().physics_frame

	# Wind-up: rings closing on the foot, tremor, the boy's marker hunting.
	_arena.boss._begin_stomp()
	await get_tree().create_timer(0.45).timeout
	await _capture("02_windup_fall_warning.png")
	await get_tree().create_timer(0.3).timeout
	# Slam: screen wave, flash, dust, chips; the stones just released.
	await get_tree().create_timer(0.06).timeout
	await _capture("03_slam.png")
	await get_tree().create_timer(0.22).timeout
	await _capture("04_stones_falling.png")
	await get_tree().create_timer(0.35).timeout
	await _capture("05_open_window.png")
	await get_tree().create_timer(1.2).timeout
	await _capture("06_after_impacts.png")
	_arena._stop_all_danger()
	_arena.boss.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame

	# Eruption warning and burst, driven straight from the arena.
	_arena._on_stomp_warning(2, 3)
	await get_tree().create_timer(0.55).timeout
	await _capture("07_eruption_warning.png")
	_arena._on_stomp_impact(2, 3)
	await get_tree().create_timer(0.16).timeout
	await _capture("08_eruption_burst.png")
	await get_tree().create_timer(0.4).timeout
	await _capture("09_shockwave_travel.png")
	_arena._stop_all_danger()
	await get_tree().process_frame

	# A sword hit in the open window, then the death.
	_arena.boss.process_mode = Node.PROCESS_MODE_INHERIT
	_arena.boss._set_vulnerable(true)
	_arena.boss.set("_state", &"recover")
	_arena.boss.receive_player_hit(34.0, _player)
	await get_tree().create_timer(0.08).timeout
	await _capture("10_open_hit.png")
	_arena.boss.health.kill(_player)
	await get_tree().create_timer(0.55).timeout
	await _capture("11_death_crumble.png")
	await get_tree().create_timer(0.6).timeout
	await _capture("12_death_rubble.png")

	print("BOSS_STONE_CAPTURES=" + OUTPUT_DIR)
	get_tree().quit()


func _capture(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(OUTPUT_DIR + "/" + name)
	assert(error == OK)
	print("CAPTURED " + name)
