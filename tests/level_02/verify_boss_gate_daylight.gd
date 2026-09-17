extends "res://tests/level_02/verify_business_boss.gd"

func check_daylight() -> void:
	check(level.get_node("NightTint").color == Color.WHITE, "Boss room retained night tint")
	var transition := level.get_node("DayNightTransition")
	for path in transition.day_fade_out:
		check(transition.get_node(path).modulate.a == 1.0, "Boss room lost a daylight layer")
	for path in transition.night_fade_in:
		check(transition.get_node(path).modulate.a == 0.0, "Boss room retained a night layer")
	check(not GameState.night_active, "Boss room still records night as active")

func enter_gate() -> void:
	var gate: BossGate = level.get_node("World/Exit/BossGate")
	var art := gate.get_node("Art") as Sprite2D
	check(art.texture.resource_path.ends_with("business_portal_gate_refined.png"), "Entrance uses the old portal")
	check(gate.get_node("Glow").texture == art.texture, "Portal glow uses different artwork")
	check(absf(art.texture.get_height() * art.scale.y - 202.0) < 1.0, "New portal changed entrance height")
	player.global_position = gate.global_position
	player.velocity = Vector2.ZERO
	await frames(150)
	check(gate._transitioning and arena.stage == arena.Stage.FIGHTING, "Actual portal overlap did not start fight")
	check(player.global_position.x >= arena.global_position.x, "Gate did not carry player into boss room")
	check(player.process_mode != Node.PROCESS_MODE_DISABLED, "Gate left player controls locked")
	check(art.scale == gate.rest_art_scale, "Portal reset to the old asset scale")
	check_daylight()

func night_route_to_boss() -> void:
	await fresh(false)
	player.global_position = Vector2(9150,640)
	await frames(150)
	check(GameState.night_active, "Level's day/night trigger no longer works")
	check(level.get_node("NightTint").color != Color.WHITE, "Level did not become night")
	GameState.set_checkpoint(&"L2NightApproach", Vector2(10050,650), 20.0, true)
	await enter_gate()
	check(GameState.checkpoint_night, "Boss entry erased checkpoint night state")

func checkpoint_and_inflight_fade() -> void:
	# A retry outside the arena must still restore the original night section.
	level.queue_free()
	await frames(2)
	level = MAP.instantiate()
	add_child(level)
	player = level.get_node("Entities/Player")
	check(GameState.night_active, "Night checkpoint reloaded in daylight")
	check(level.get_node("Background/Sky/NightGradient").modulate.a == 1.0, "Night checkpoint lost background")
	# Direct/debug entry can happen while the crossfade is still running.
	await fresh(false)
	var transition := level.get_node("DayNightTransition")
	transition._on_body_entered(player)
	await frames(10)
	player.global_position = arena.get_node("PlayerSpawn").global_position
	arena.prepare_gate_entry(player)
	await frames(150)
	check_daylight()

func _ready() -> void:
	await night_route_to_boss()
	await checkpoint_and_inflight_fade()
	TimeService.reset()
	level.queue_free()
	await frames(2)
	print("BOSS_GATE_DAYLIGHT_VERIFIED failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
