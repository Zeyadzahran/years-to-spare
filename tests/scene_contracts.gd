extends SceneTree
## Run with: godot --headless --path . --script tests/scene_contracts.gd
## Covers the gameplay identities and navigation that scene moves must preserve.
## Add -- --level-only to check Level 01 without running menus or cinematics.

const LEVEL := "res://src/levels/level_01/level_01.tscn"
const LEVEL_02 := "res://src/levels/level_02/level_02.tscn"
const FIRST_TITLE := "res://src/ui/level_title/level_01_title.tscn"
const CITY_TITLE := "res://src/ui/level_title/city_of_time_title.tscn"
const ENEMY_PATHS := [
	"Enemies/Guard1", "Enemies/Gunner1", "Enemies/Guard2", "Enemies/Gunner2",
	"Enemies/Gunner3", "Enemies/Gunner4", "Enemies/Guard", "Enemies/Gunner",
	"World/SalvageYard/Enemies/DockGuard", "World/SalvageYard/Enemies/FreightGuard",
]
var failures := 0
var loaded_scenes := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func check_scenes(directory: String) -> void:
	for folder in DirAccess.get_directories_at(directory):
		check_scenes(directory.path_join(folder))
	for file in DirAccess.get_files_at(directory):
		if not file.ends_with(".tscn"):
			continue
		var path := directory.path_join(file)
		var scene := load(path) as PackedScene
		check(scene != null, "Cannot load " + path)
		if scene != null:
			var instance := scene.instantiate()
			check(instance != null, "Cannot instantiate " + path)
			if instance != null:
				instance.free()
			loaded_scenes += 1

func run() -> void:
	create_timer(30.0).timeout.connect(func():
		push_error("Scene contracts timed out waiting for navigation")
		quit(1)
	)
	check_scenes("res://src")
	var level_only := "--level-only" in OS.get_cmdline_user_args()
	if not level_only:
		change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
		await scene_changed
		await scene_changed
		check(current_scene.scene_file_path == "res://src/ui/main_menu/main_menu.tscn", "Startup did not reach main menu")
		current_scene.get_node("VBoxContainer/Credits").pressed.emit()
		await scene_changed
		check(current_scene.scene_file_path == "res://src/ui/credits/credits.tscn", "Credits button destination changed")
		current_scene._on_back_button_pressed()
		await scene_changed
		check(current_scene.scene_file_path == "res://src/ui/main_menu/main_menu.tscn", "Credits did not return to main menu")
		current_scene.free()
	var state := root.get_node("GameState")
	state.clear_run_progress()
	var level: Node2D = load(LEVEL).instantiate()
	level.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(level)
	current_scene = level
	await process_frame
	for path in ENEMY_PATHS:
		check(level.has_node(path), "Enemy retry identity changed: " + path)
		if level.has_node(path):
			check(level._tag(level.get_node(path)) == path, "Enemy tag changed")
	for checkpoint in ["Checkpoint1", "Checkpoint2", "Checkpoint3", "Checkpoint"]:
		check(level.has_node("World/Checkpoints/" + checkpoint), "Missing checkpoint " + checkpoint)
	var checkpoint_names: Array[StringName] = []
	for checkpoint in level.find_children("*", "Checkpoint", true, false):
		check(not checkpoint.name in checkpoint_names, "Duplicate checkpoint identity: " + checkpoint.name)
		checkpoint_names.append(checkpoint.name)
	check(checkpoint_names.size() == 8, "Expected all eight authored checkpoints")

	# A defeated enemy stays defeated after reloading; age and checkpoint survive.
	state.clear_enemy(&"phase_1", "Enemies/Guard1")
	state.set_checkpoint(&"Checkpoint", Vector2(9198, 604), 31.0)
	level.free()
	level = load(LEVEL).instantiate()
	level.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(level)
	current_scene = level
	await process_frame
	check(not level.has_node("Enemies/Guard1"), "Defeated guard returned on retry")
	check(level.has_node("Enemies/Guard2"), "An undefeated guard was removed")
	var player = level.get_node("Entities/Player")
	check(player.global_position == Vector2(9198, 604), "Checkpoint position changed")
	check(player.age.age == 31.0, "Retry age changed")
	check(level.get_node("World/Checkpoints/Checkpoint/Marker").animation == &"green", "Active checkpoint lost its marker")

	var exit_area := level.get_node("World/SalvageYard/Gates/LevelExit")
	var stranger := Node2D.new()
	exit_area.body_entered.emit(stranger)
	check(not exit_area._completed, "Non-player triggered exit")
	stranger.free()
	exit_area.body_entered.emit(player)
	check(exit_area._completed, "Player did not trigger exit")
	exit_area.body_entered.emit(player)
	await process_frame
	check(paused, "Completion must pause the level")
	check(exit_area.get_node("Completion/Panel").visible, "Completion panel missing")
	paused = false
	current_scene.free()
	state.clear_run_progress()
	if not level_only:
		for title_and_target in [[CITY_TITLE, LEVEL_02], [FIRST_TITLE, LEVEL]]:
			var title: String = title_and_target[0]
			var target: String = title_and_target[1]
			change_scene_to_file(title)
			await scene_changed
			await scene_changed
			check(current_scene.scene_file_path == target, "Title destination changed: " + title)
			current_scene.free()
	await process_frame
	# Give the audio server time to release playbacks after the final scene closes.
	await create_timer(0.1).timeout
	print("Scene contracts: ", loaded_scenes, " scenes loaded; failures=", failures)
	quit(1 if failures > 0 else 0)
