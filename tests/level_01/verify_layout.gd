extends Node
## Current transfer layout; timed traversal has its own controller check.

const FIXTURE = preload("res://tests/level_01/fixture.gd")


func _ready() -> void:
	var section := FIXTURE.late_sections()
	add_child(section)
	await get_tree().physics_frame
	var terrain := section.get_node(^"Terrain") as TileMapLayer
	var used := terrain.get_used_rect()
	assert(used.has_point(Vector2i(125, 1)) and used.has_point(Vector2i(133, 1)))
	var platforms := section.get_node(^"Platforms")
	assert(platforms.get_child_count() <= 10)
	for name in ["Shuttle", "FreightLift", "TransferIn", "TransferRest",
			"TransferOut", "HealingLedge"]:
		assert(platforms.has_node(NodePath(name)), "Missing beat: " + name)
	# Short cycles keep a missed boarding opportunity from becoming a long wait.
	var moving_count := 0
	for deck in platforms.get_children():
		if deck is MovingPlatform:
			moving_count += 1
			assert(deck.travel.length() * 2.0 / deck.speed <= 5.0)
			assert(deck.size.x >= 200)
	assert(moving_count == 4)
	assert(section.get_node(^"Checkpoints").get_child_count() == 4)
	assert(section.has_node(^"Checkpoints/ExitCheckpoint"))
	assert(section.get_node(^"Enemies").get_child_count() <= 4)
	assert(section.get_node(^"Decorations").get_child_count() >= 60)
	assert(section.has_node(^"Gates/LevelExit"))
	assert(not section.has_node(^"Enemies/Warden"))
	assert(get_tree().get_nodes_in_group(&"warden_phase_two").is_empty())
	assert(get_tree().get_nodes_in_group(&"warden_phase_three").is_empty())
	# The hardest optional jump leads to a visible healing reward.
	var ledge := platforms.get_node(^"HealingLedge") as Node2D
	var fig := section.get_node(^"Pickups/HighLedgeFig") as Node2D
	assert(absf(ledge.position.x - fig.position.x) < 60)
	assert(fig.position.y < ledge.position.y)
	# The former recovery route is now the user-requested lethal spike floor.
	assert(not platforms.has_node(^"RecoveryLow") and not platforms.has_node(^"RecoveryHigh"))
	for index in range(1, 6):
		var spike := section.get_node("Hazards/TransferSpikes%02d" % index) as Hazard
		assert(spike.damage >= 100 and spike.hurts_while_frozen)
	for x in range(126, 133):
		assert(terrain.get_cell_source_id(Vector2i(x, 3)) != -1)
	print("COMPACT_LAYOUT_OK length=%d platforms=%d decorations=%d enemies=%d" % [
		(used.end.x - used.position.x) * 120, platforms.get_child_count(),
		section.get_node(^"Decorations").get_child_count(), section.get_node(^"Enemies").get_child_count()])
	section.queue_free()
	await get_tree().process_frame
	get_tree().quit()
