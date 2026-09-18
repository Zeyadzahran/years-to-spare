extends "res://tests/level_02/verify_boss_retries.gd"

func press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)

func wait_for_prompt() -> Node:
	for i in 60:
		await frames(1)
		if player.has_node("DeathPrompt"):
			return player.get_node("DeathPrompt")
	check(false, "Death prompt did not appear")
	return null

func paused_rewind(hearts := 3, lethal_fall := false) -> void:
	await fresh(false)
	GameState.hearts = hearts
	player.global_position = Vector2(600,640)
	await frames(240)
	if lethal_fall:
		level.get_node("World/Hazards/FallReset")._hurt(player)
	else:
		player.health.kill()
	await frames(10)
	check(not get_tree().paused, "Death skipped its collapse animation")
	var prompt := await wait_for_prompt()
	if prompt == null: return
	check(not player.powers.is_casting(GameState.ABILITY_REWIND), "Death automatically started rewind")
	check(is_equal_approx(player.age.age, 14.0), "Death spent years before choosing Rewind")
	check(prompt.rewind_button.visible, "Available Rewind was hidden")
	var continue_text := "[ENTER] RESTART LEVEL" if hearts == 1 else "[ENTER] CONTINUE"
	check(prompt.continue_button.text == continue_text, "Wrong remaining-heart option")
	var history_time := TimeService._now
	var dead_position := player.position
	await frames(360)
	check(get_tree().paused and TimeService._now == history_time, "Choice screen consumed rewind history")
	check(player.position == dead_position and GameState.hearts == hearts, "Waiting moved player or spent a heart")
	press_key(KEY_ESCAPE)
	check(get_tree().paused and not is_instance_valid(level.get_node("HUD")._options_panel), "Escape opened a competing pause menu")
	press_key(KEY_L)
	await frames(1)
	check(not get_tree().paused, "L failed to resume the paused game")
	await frames(140)
	check(player.health.is_alive() and not player.is_down(), "Death-screen Rewind did not revive player")
	check(GameState.hearts == hearts and level.reload_count == 0, "Rewind committed the death")
	check(is_equal_approx(player.age.age, 18.0), "Death-screen Rewind charged the wrong age cost")
	print("DEATH_CHOICE rewind preserves history, heart and live scene")

func unavailable_options() -> void:
	for reason in ["cooldown", "old_age", "locked", "age_cost", "history"]:
		await fresh(false)
		player.global_position = Vector2(600,640)
		await frames(90)
		match reason:
			"cooldown": player.powers._cooldowns[GameState.ABILITY_REWIND] = 5.0
			"locked": GameState.unlocked.erase(GameState.ABILITY_REWIND)
			"age_cost": player.age.set_to(56.0)
			"history": TimeService.reset()
		if reason == "old_age":
			player.age.spend(60.0)
		else:
			player.health.kill()
		var prompt := await wait_for_prompt()
		if prompt == null: return
		check(not prompt.rewind_button.visible, "%s incorrectly offered Rewind" % reason)
		var remaining := player.powers.cooldown_left(GameState.ABILITY_REWIND)
		await frames(360)
		check(player.powers.cooldown_left(GameState.ABILITY_REWIND) == remaining, "Paused choice cleared cooldown")
		press_key(KEY_L)
		await frames(1)
		check(get_tree().paused, "Unavailable L dismissed the death screen")
		var restart: bool = reason == "old_age"
		check(prompt.continue_button.text == ("[ENTER] RESTART LEVEL" if restart else "[ENTER] CONTINUE"), "Wrong continuation for %s" % reason)
		press_key(KEY_ENTER)
		await frames(2)
		check(not get_tree().paused and level.reload_count == 1, "Enter did not continue for %s" % reason)
		check(GameState.hearts == (3 if restart else 2), "Wrong hearts after %s" % reason)
	print("DEATH_CHOICE cooldown, old age, unlock, age cost, missing history")

func last_heart_restart() -> void:
	await fresh(false)
	GameState.hearts = 1
	player.global_position = Vector2(600,640)
	await frames(90)
	player.health.kill()
	var prompt := await wait_for_prompt()
	if prompt == null: return
	check(prompt.rewind_button.visible, "Last heart did not offer Rewind")
	check(prompt.continue_button.text == "[ENTER] RESTART LEVEL", "Last heart did not offer Restart")
	press_key(KEY_ENTER)
	await frames(2)
	check(not get_tree().paused and level.reload_count == 1, "Last-heart Restart did not reload")
	check(GameState.hearts == GameState.MAX_HEARTS and GameState.run_age < 0.0, "Last-heart Restart did not reset the run")
	print("DEATH_CHOICE last heart can restart instead of rewinding")

func actual_checkpoint_reload() -> void:
	level.queue_free()
	await frames(2)
	GameState.clear_run_progress()
	level = MAP.instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	player = level.get_node("Entities/Player")
	GameState.set_checkpoint(&"L2MachineYard", Vector2(1691,652), 20.0)
	player.age.set_to(20.0)
	await frames(5)
	player.health.kill()
	await wait_for_prompt()
	press_key(KEY_ENTER)
	await frames(12)
	level = get_tree().current_scene as Level
	player = level.get_node("Entities/Player")
	check(not get_tree().paused and player.health.is_alive(), "Real scene reload stayed paused or dead")
	check(GameState.hearts == 2 and is_equal_approx(player.age.age, 20.0), "Real reload lost age or heart count")
	check(player.position.distance_to(Vector2(1691,640)) < 2.0, "Continue did not restore checkpoint")
	get_tree().current_scene = self
	print("DEATH_CHOICE real checkpoint reload resumes at saved position")

func _ready() -> void:
	await paused_rewind()
	await paused_rewind(1)
	await paused_rewind(3, true)
	await unavailable_options()
	await last_heart_restart()
	await actual_checkpoint_reload()
	TimeService.reset()
	level.queue_free()
	await frames(2)
	print("DEATH_CHOICE_VERIFIED failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
