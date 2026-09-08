extends Node
## Renders the integrated production level at its major gameplay beats.

const LEVEL := "res://src/levels/level_01.tscn"
const EXTENSION := "res://src/levels/level_01_production_extension.tscn"
const OUTPUT_DIR := "res://verification/production_greybox"
const SHOTS := [
	{"name": "01_broken_lift", "position": Vector2(12550, 100)},
	{"name": "02_freight_rise", "position": Vector2(14050, -20)},
	{"name": "03_saw_run", "position": Vector2(17720, -120)},
	{"name": "04_route_fork", "position": Vector2(20340, 0)},
	{"name": "05_route_split", "position": Vector2(22780, 220)},
	{"name": "06_route_reunion", "position": Vector2(27780, 100)},
	{"name": "07_the_drop", "position": Vector2(30050, 250)},
	{"name": "08_orbit_yard", "position": Vector2(32500, 650)},
	{"name": "09_collapse_rise", "position": Vector2(34200, 600)},
	{"name": "10_arena", "position": Vector2(37600, 350)},
	{"name": "11_warden_gate", "position": Vector2(38600, 350)},
]


func _ready() -> void:
	get_tree().root.size = Vector2i(1280, 720)
	var level := (load(LEVEL) as PackedScene).instantiate()
	add_child(level)
	var world := level.get_node(^"World")
	var live_extension := world.get_node(^"FiveActExtension") as Node2D
	assert(live_extension.scene_file_path == EXTENSION)
	await get_tree().process_frame
	await get_tree().process_frame

	var player := get_tree().get_first_node_in_group(&"player") as Player
	assert(player != null)
	var camera := player.get_node(^"Camera2D") as Camera2D
	camera.position_smoothing_enabled = false
	camera.zoom = Vector2(1.25, 1.25)
	get_tree().paused = true

	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(output_path)
	for shot: Dictionary in SHOTS:
		player.global_position = shot["position"]
		player.velocity = Vector2.ZERO
		camera.reset_smoothing()
		await get_tree().process_frame
		await get_tree().process_frame
		RenderingServer.force_draw()
		await get_tree().process_frame
		var image := get_tree().root.get_texture().get_image()
		var path := "%s/%s.png" % [output_path, shot["name"]]
		assert(image.save_png(path) == OK)
		print("CAPTURED %s" % path)

	get_tree().paused = false
	get_tree().quit()
