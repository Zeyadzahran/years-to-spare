extends Node
## Final integration and pacing gate for the shipped Level 01 scene.

const LEVEL := "res://src/levels/level_01.tscn"
const EXTENSION := "res://src/levels/level_01_production_extension.tscn"


func _ready() -> void:
	var level := (load(LEVEL) as PackedScene).instantiate()
	add_child(level)
	await get_tree().physics_frame
	var extension := level.get_node(^"World/FiveActExtension") as Node2D
	assert(extension.scene_file_path == EXTENSION)
	# The extension must sit at the origin. Offsetting it by (70, -87) put a 70px
	# gap and an 87px step in the seam with Act 1: the original terrain ends at
	# tile 97 and the extension starts at tile 98, both with their surface at 240,
	# so they only meet cleanly at zero.
	assert(extension.position.is_equal_approx(Vector2.ZERO))

	var player := get_tree().get_first_node_in_group(&"player") as Player
	assert(player != null)
	assert(is_equal_approx(player.jump_velocity, -900.0))
	assert(is_equal_approx(player.floor_snap_length, 16.0))
	assert(extension.has_node(^"Gates/EndGateLandmark"))
	assert(extension.has_node(^"Enemies/Warden"))

	# The only labels inside the extension belong to the victory panel. Route
	# choice is communicated through geometry and motion, never instruction text.
	var labels := extension.find_children("*", "Label", true, false)
	assert(labels.size() == 3)
	for label in labels:
		assert(String(label.get_path()).contains("Warden/Victory"))

	# Transparent pacing model for first-play tuning. It is deliberately based
	# on authored content rather than a fake countdown: navigation below max
	# speed, one compact exchange per unit, hazard reads, and the boss exam.
	# Read the finish from the terrain rather than a constant: the old 39000 was
	# measured with the extension offset by (70, -87), so it drifted the moment
	# that offset was corrected to zero.
	var end_terrain := extension.get_node(^"Terrain") as TileMapLayer
	var finish_x := extension.position.x + end_terrain.get_used_rect().end.x * 120.0
	var raw_run_seconds := (finish_x - player.position.x) / player.speed
	var enemy_count := get_tree().get_nodes_in_group(&"enemy").size()
	var hazard_count := extension.get_node(^"Hazards").get_child_count()
	var estimated_first_play := raw_run_seconds / 0.72 \
		+ enemy_count * 4.0 + hazard_count * 1.5 + 35.0
	assert(estimated_first_play >= 300.0)
	print("PRODUCTION_LEVEL_OK enemies=%d hazards=%d raw_run=%.1fs first_play_estimate=%.1fs" % [
		enemy_count, hazard_count, raw_run_seconds, estimated_first_play,
	])
	get_tree().quit()
