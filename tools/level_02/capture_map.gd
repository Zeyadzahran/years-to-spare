extends Node
## Render the saved scene at its actual gameplay zoom; no layout is generated.
func _ready() -> void:
	SettingsManager.fullscreen = false
	SettingsManager.apply_fullscreen()
	get_tree().root.size = Vector2i(1280,720)
	GameState.clear_run_progress()
	var level: Node2D = load("res://src/levels/level_02/level_02.tscn").instantiate()
	add_child(level)
	await get_tree().process_frame
	get_tree().paused = true
	await get_tree().create_timer(1.0, true).timeout
	SettingsManager.apply_fullscreen()
	get_tree().root.size = Vector2i(1280,720)
	var player := level.get_node("Entities/Player") as Player
	var camera := player.get_node("Camera2D") as Camera2D
	camera.position_smoothing_enabled = false
	DirAccess.make_dir_recursive_absolute("res://builds/level-02-review")
	for shot in [["01-entry",Vector2(400,640)],["02-machinery",Vector2(2360,640)],["03-rooftops",Vector2(3740,512)],["04-freight",Vector2(4540,512)],["05-courtyard",Vector2(6960,640)],["06-exit",Vector2(8560,640)]]:
		player.position = shot[1]
		camera.reset_smoothing()
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://builds/level-02-review/%s.png" % shot[0])
		print("CAPTURED ",shot[0])
	level.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	get_tree().quit()
