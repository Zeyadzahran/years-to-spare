extends "res://tests/level_02/verify_boss_retries.gd"
## Death flow: a spare heart costs the heart and reloads on its own, with no
## screen in the way; the last heart (or old age) stops on Game Over, where
## Enter restarts the level and Q leaves for the menu.

func press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)

func wait_for_screen() -> Node:
	for i in 60:
		await frames(1)
		if player.has_node("GameOver"):
			return player.get_node("GameOver")
	check(false, "Game Over screen did not appear")
	return null

func spare_heart_is_silent() -> void:
	for hearts in [3, 2]:
		await fresh(false)
		GameState.hearts = hearts
		player.global_position = Vector2(600,640)
		await frames(90)
		player.health.kill()
		for i in 60:
			await frames(1)
			if level.reload_count > 0:
				break
		check(level.reload_count == 1, "Death with %d hearts did not reload on its own" % hearts)
		check(GameState.hearts == hearts - 1, "Death with %d hearts did not cost exactly one" % hearts)
		check(not get_tree().paused and not player.has_node("GameOver"), "Death with %d hearts put a screen up" % hearts)
	print("DEATH_CHOICE a spare heart is spent without a screen")

func last_heart_stops() -> void:
	for reason in ["hearts", "old_age"]:
		await fresh(false)
		player.global_position = Vector2(600,640)
		await frames(90)
		if reason == "old_age":
			player.age.spend(60.0)
		else:
			GameState.hearts = 1
			player.health.kill()
		var screen := await wait_for_screen()
		if screen == null: return
		check(get_tree().paused, "Game Over did not pause for %s" % reason)
		check(screen.restart_button.text == "[ENTER] RESTART LEVEL" and screen.quit_button.text == "[Q] QUIT TO MENU", "Wrong Game Over options for %s" % reason)
		var reload_before: int = level.reload_count
		await frames(120)
		check(get_tree().paused and level.reload_count == reload_before, "Game Over resolved itself for %s" % reason)
		press_key(KEY_ESCAPE)
		check(get_tree().paused and not is_instance_valid(level.get_node("HUD")._options_panel), "Escape opened a competing pause menu")
		press_key(KEY_ENTER)
		await frames(2)
		check(not get_tree().paused and level.reload_count == 1, "Enter did not restart for %s" % reason)
		check(GameState.hearts == GameState.MAX_HEARTS and GameState.run_age < 0.0, "Restart did not reset the run for %s" % reason)
	print("DEATH_CHOICE last heart and old age stop on Game Over; Enter restarts")

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
	await frames(60)
	level = get_tree().current_scene as Level
	player = level.get_node("Entities/Player")
	check(not get_tree().paused and player.health.is_alive(), "Real scene reload stayed paused or dead")
	check(GameState.hearts == 2 and is_equal_approx(player.age.age, 20.0), "Real reload lost age or heart count")
	check(player.position.distance_to(Vector2(1691,640)) < 2.0, "Reload did not restore checkpoint")
	get_tree().current_scene = self
	print("DEATH_CHOICE real checkpoint reload resumes at saved position")

func _ready() -> void:
	await spare_heart_is_silent()
	await last_heart_stops()
	await actual_checkpoint_reload()
	TimeService.reset()
	level.queue_free()
	await frames(2)
	print("DEATH_CHOICE_VERIFIED failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
