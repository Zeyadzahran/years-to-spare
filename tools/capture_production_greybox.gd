extends Node
## Renders Level 01 directly, without opening the menu or story.
## Use tools/capture_level.py to capture and build a browsable gallery.

const LEVEL := "res://src/levels/level_01.tscn"
const OUTPUT_DIR := "res://builds/level-review"
const SHOTS := [
	{"name": "00a_opening", "position": Vector2(337, 606)},
	{"name": "00b_attack", "position": Vector2(820, 606)},
	{"name": "00c_healing", "position": Vector2(1350, 606)},
	{"name": "00d_time_stop", "position": Vector2(2010, 606)},
	{"name": "00e_level_join", "position": Vector2(11760, 240)},
	{"name": "01_shuttle", "position": Vector2(12400, 219)},
	{"name": "02_dock", "position": Vector2(13030, 239)},
	{"name": "03_freight_lift", "position": Vector2(13740, 359)},
	{"name": "04_healing_ledge", "position": Vector2(14080, -1)},
	{"name": "05_transfer_start", "position": Vector2(15050, 119)},
	{"name": "06_transfer_aligned", "position": Vector2(15541, -139.5), "transfer_phase": 0.67},
	{"name": "07_spike_floor", "position": Vector2(15430, 250)},
	{"name": "08_exit_approach", "position": Vector2(16400, 119)},
	{"name": "09_exit", "node": ^"Gates/LevelExit", "offset": Vector2(-110, 0)},
	{"name": "10_completion", "node": ^"Gates/LevelExit", "offset": Vector2.ZERO, "complete": true},
]


func _ready() -> void:
	# Runtime override only: keep captures windowed without changing saved settings.
	SettingsManager.fullscreen = false
	SettingsManager.apply_fullscreen()
	get_tree().root.size = Vector2i(1280, 720)
	GameState.clear_run_progress()
	var level := (load(LEVEL) as PackedScene).instantiate()
	add_child(level)
	var world := level.get_node(^"World")
	var live_extension := world.get_node(^"FiveActExtension") as Node2D
	assert(live_extension.scene_file_path.is_empty())
	assert(live_extension.owner == level)
	await get_tree().process_frame
	await get_tree().process_frame

	get_tree().root.size = Vector2i(1280, 720)

	var player := get_tree().get_first_node_in_group(&"player") as Player
	assert(player != null)
	var camera := player.get_node(^"Camera2D") as Camera2D
	camera.position_smoothing_enabled = false
	# Keep the real gameplay zoom: a wider review camera can hide blind jumps.
	get_tree().paused = true
	# macOS finishes native fullscreen transitions asynchronously. Apply the
	# capture window after startup has settled, without saving user preferences.
	await get_tree().create_timer(1.0, true).timeout
	SettingsManager.apply_fullscreen()
	await get_tree().create_timer(1.0, true).timeout
	get_tree().root.size = Vector2i(1280, 720)
	await get_tree().process_frame
	print("CAPTURE_VIEWPORT size=%s mode=%d" % [get_tree().root.size, get_tree().root.mode])

	var only := PackedStringArray()
	var captured := 0
	var output_path := ProjectSettings.globalize_path(OUTPUT_DIR)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--only="):
			only = argument.trim_prefix("--only=").split(",", false)
		if argument.begins_with("--output="):
			output_path = argument.trim_prefix("--output=")
	assert(DirAccess.make_dir_recursive_absolute(output_path) == OK)
	for shot: Dictionary in SHOTS:
		if not only.is_empty():
			var selected := false
			for prefix in only:
				if String(shot["name"]).begins_with(prefix): selected = true
			if not selected: continue
		if shot.has("node"):
			player.global_position = live_extension.get_node(shot["node"]).global_position + shot["offset"]
		else:
			player.global_position = shot["position"]
		if shot.has("transfer_phase"):
			for deck_name in ["TransferIn", "TransferOut"]:
				var deck := live_extension.get_node("Platforms/" + deck_name) as MovingPlatform
				deck.position = deck.get("_origin") + deck.travel * float(shot["transfer_phase"])
		player.velocity = Vector2.ZERO
		if shot.get("complete", false):
			live_extension.get_node(^"Gates/LevelExit")._on_body_entered(player)
		camera.reset_smoothing()
		await get_tree().process_frame
		await get_tree().process_frame
		RenderingServer.force_draw()
		await get_tree().process_frame
		var image := get_tree().root.get_texture().get_image()
		var path := "%s/%s.png" % [output_path, shot["name"]]
		assert(image.save_png(path) == OK)
		captured += 1
		print("CAPTURED %s" % path)

	print("CAPTURE_COMPLETE count=%d" % captured)
	get_tree().paused = false
	level.queue_free()
	await get_tree().process_frame
	get_tree().quit()
