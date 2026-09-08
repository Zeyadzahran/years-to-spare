extends Node
## Structural gate for Phase 2. Gameplay enemies and hazards intentionally
## remain absent until this traversal-only blockout passes review.

const EXTENSION := "res://src/levels/level_01_production_extension.tscn"


func _ready() -> void:
	var extension := (load(EXTENSION) as PackedScene).instantiate()
	add_child(extension)
	await get_tree().physics_frame

	var terrain := extension.get_node(^"Terrain") as TileMapLayer
	var used := terrain.get_used_rect()
	assert(used.position.x == 98)
	assert(used.end.x == 327)
	# Act 2 now climbs to a peak before its cliff, so the terrain reaches higher
	# than the old flat profile did. Bound it rather than pin it.
	assert(used.position.y <= -1)
	assert(used.end.y == 19)
	assert(terrain.get_used_cells().size() > 3200)

	var platforms := extension.get_node(^"Platforms")
	# A floor, not a pin: deepening the fork bowl to two-tile terraces needed
	# three more decks to keep the Long Way climbable on its own.
	assert(platforms.get_child_count() >= 49)
	for required in [
		^"BrokenLiftShuttle", ^"FreightElevator", ^"SawRunFallingDeck",
		^"AgeCutFall03", ^"AgeCutBlink06", ^"AgeCutAnchor03", ^"BowlLift",
		^"LongWayShuttle", ^"OrbitDeckOuter", ^"OrbitDeckInner",
		^"Collapse03", ^"FiringLineLift",
	]:
		assert(platforms.has_node(required), "Missing traversal beat: %s" % required)

	var horizontal := platforms.get_node(^"BrokenLiftShuttle") as MovingPlatform
	var vertical := platforms.get_node(^"FreightElevator") as MovingPlatform
	var orbit := platforms.get_node(^"OrbitDeckOuter") as MovingPlatform
	var blink := platforms.get_node(^"AgeCutBlink01") as BlinkPlatform
	var falling := platforms.get_node(^"Collapse01") as FallingPlatform
	assert(horizontal.travel.x > 400.0 and is_zero_approx(horizontal.travel.y))
	assert(vertical.travel.y < -300.0 and is_zero_approx(vertical.travel.x))
	assert(orbit.motion_mode == MovingPlatform.MotionMode.ORBIT)
	assert(blink.visible_time > blink.hidden_time)
	assert(falling.delay >= 0.7)

	# Every authored stepping-stone jump stays inside the oldest player's measured
	# 253.5px edge-to-edge reach. Dynamic transfers get their own playtest gate.
	for pair in [
		[^"FreightStep01", ^"FreightStep02"],
		[^"FreightStep02", ^"FreightStep03"],
		[^"ForkHighStep", ^"AgeCutLink01"],
		[^"AgeCutLink01", ^"AgeCutFall01"],
		[^"AgeCutFall01", ^"AgeCutBlink01"],
		[^"AgeCutBlink01", ^"AgeCutAnchor01"],
		[^"AgeCutAnchor01", ^"AgeCutFall02"],
		[^"AgeCutFall02", ^"AgeCutBlink03"],
		[^"AgeCutBlink03", ^"AgeCutLink02"],
		[^"AgeCutLink02", ^"AgeCutBlink04"],
		[^"AgeCutBlink04", ^"AgeCutFall03"],
		[^"AgeCutFall03", ^"AgeCutAnchor03"],
		[^"AgeCutAnchor03", ^"AgeCutBlink06"],
		[^"AgeCutBlink06", ^"AgeCutLink03"],
		[^"AgeCutLink03", ^"AgeCutShuttle"],
		[^"AgeCutLink04", ^"AgeCutExit"],
		[^"Collapse01", ^"Collapse02"],
		[^"Collapse02", ^"Collapse03"],
		[^"Collapse03", ^"Collapse04"],
	]:
		var a = platforms.get_node(pair[0])
		var b = platforms.get_node(pair[1])
		var edge_gap: float = absf(b.position.x - a.position.x) - (a.size.x + b.size.x) * 0.5
		assert(edge_gap <= 253.5, "Elder jump too wide: %s gap=%.1f" % [pair, edge_gap])
		assert(absf(b.position.y - a.position.y) <= 120.0, "Jump too tall: %s" % [pair])
	var age_shuttle := platforms.get_node(^"AgeCutShuttle") as MovingPlatform
	var age_link := platforms.get_node(^"AgeCutLink04")
	var shuttle_end := age_shuttle.position + age_shuttle.travel
	var shuttle_exit_gap: float = absf(age_link.position.x - shuttle_end.x) \
		- (age_shuttle.size.x + age_link.size.x) * 0.5
	assert(shuttle_exit_gap <= 253.5)

	assert(extension.get_node(^"Enemies").get_child_count() == 22)
	assert(extension.get_node(^"Hazards").get_child_count() == 17)
	assert(extension.get_node(^"Pickups").get_child_count() == 5)
	# Scenery is scattered across the finished terrain rather than hand-listed,
	# so this is a floor, not a fixed count. Eleven props over 27,000px was the
	# level reading as empty; anything under ~60 has regressed to that.
	assert(extension.get_node(^"Decorations").get_child_count() >= 60)
	assert(extension.get_node(^"Gates").get_child_count() == 1)
	assert(extension.get_node(^"Checkpoints").get_child_count() == 5)
	var warden := extension.get_node(^"Enemies/Warden") as Warden
	assert(warden.health.max_health == 340.0)
	assert(get_tree().get_nodes_in_group(&"warden_phase_two").size() == 2)
	assert(get_tree().get_nodes_in_group(&"warden_phase_three").size() == 2)
	for gunner in get_tree().get_nodes_in_group(&"warden_phase_two"):
		assert(is_zero_approx(gunner.detection_range))
	for blade in get_tree().get_nodes_in_group(&"warden_phase_three"):
		assert(not blade.visible and not blade.monitoring)
	warden.health.current = 200.0
	await get_tree().physics_frame
	for gunner in get_tree().get_nodes_in_group(&"warden_phase_two"):
		assert(gunner.detection_range == 440.0)
	warden.health.current = 100.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	for blade in get_tree().get_nodes_in_group(&"warden_phase_three"):
		assert(blade.visible and blade.monitoring)
	print("PRODUCTION_LAYOUT_OK cells=%d platforms=%d enemies=22 hazards=17 checkpoints=5" % [
		terrain.get_used_cells().size(), platforms.get_child_count(),
	])
	get_tree().quit()
