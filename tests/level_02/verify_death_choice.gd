extends "res://tests/level_02/verify_boss_retries.gd"
## Death flow: after the collapse there is a window in which L still rewinds
## and nothing is on screen; when it passes, a spare heart is spent and the
## level reloads on its own, while the last heart (or old age) stops on Game
## Over, where Enter restarts the level and Q leaves for the menu.

const COLLAPSE_FRAMES := 40
const GRACE_FRAMES := 60

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
	for i in 180:
		await frames(1)
		if player.has_node("GameOver"):
			return player.get_node("GameOver")
	check(false, "Game Over screen did not appear")
	return null

func rewind_in_the_window() -> void:
	for hearts in [3, 1]:
		await fresh(false)
		GameState.hearts = hearts
		player.global_position = Vector2(600,640)
		await frames(90)
		player.health.kill()
		await frames(COLLAPSE_FRAMES + 20)
		check(player.is_down() and not get_tree().paused and not player.has_node("GameOver"), "Something came up before the window with %d hearts" % hearts)
		press_key(KEY_L)
		await frames(140)
		check(player.health.is_alive() and not player.is_down(), "L in the window did not revive him with %d hearts" % hearts)
		check(GameState.hearts == hearts and level.reload_count == 0, "Rewind in the window still committed the death")
		check(is_equal_approx(player.age.age, 18.0), "Rewind charged the wrong years")
	print("DEATH_CHOICE L inside the window rewinds, on any heart")

func window_passes() -> void:
	for hearts in [3, 2]:
		await fresh(false)
		GameState.hearts = hearts
		player.global_position = Vector2(600,640)
		await frames(90)
		player.health.kill()
		for i in 180:
			await frames(1)
			if level.reload_count > 0:
				break
		check(level.reload_count == 1, "Death with %d hearts did not reload on its own" % hearts)
		check(GameState.hearts == hearts - 1, "Death with %d hearts did not cost exactly one" % hearts)
		check(not get_tree().paused and not player.has_node("GameOver"), "Death with %d hearts put a screen up" % hearts)
		# Too late: the press does nothing once the heart is spent.
		press_key(KEY_L)
		await frames(30)
		check(not player.powers.is_casting(GameState.ABILITY_REWIND) and GameState.hearts == hearts - 1, "A late L still rewound")
	print("DEATH_CHOICE a spare heart is spent without a screen once the window passes")

func blocked_rewind_is_silent() -> void:
	await fresh(false)
	player.global_position = Vector2(600,640)
	await frames(90)
	player.powers._cooldowns[GameState.ABILITY_REWIND] = 5.0
	player.health.kill()
	await frames(COLLAPSE_FRAMES + 20)
	press_key(KEY_L)
	await frames(10)
	check(player.is_down() and not player.powers.is_casting(GameState.ABILITY_REWIND), "Cooling Rewind was cast from the grave")
	for i in 180:
		await frames(1)
		if level.reload_count > 0:
			break
	check(level.reload_count == 1 and GameState.hearts == 2 and not get_tree().paused, "Blocked rewind did not fall through to a plain death")
	print("DEATH_CHOICE a blocked rewind is just a death")

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
	GameState.rewind_lesson_done = true
	level = MAP.instantiate()
	get_tree().root.add_child(level)
	get_tree().current_scene = level
	player = level.get_node("Entities/Player")
	GameState.set_checkpoint(&"L2MachineYard", Vector2(1340,652), 20.0)
	player.age.set_to(20.0)
	await frames(5)
	player.health.kill()
	await frames(COLLAPSE_FRAMES + GRACE_FRAMES + 20)
	level = get_tree().current_scene as Level
	player = level.get_node("Entities/Player")
	check(not get_tree().paused and player.health.is_alive(), "Real scene reload stayed paused or dead")
	check(GameState.hearts == 2 and is_equal_approx(player.age.age, 20.0), "Real reload lost age or heart count")
	check(player.position.distance_to(Vector2(1340,640)) < 2.0, "Reload did not restore checkpoint")
	get_tree().current_scene = self
	print("DEATH_CHOICE real checkpoint reload resumes at saved position")

func _ready() -> void:
	await rewind_in_the_window()
	await window_passes()
	await blocked_rewind_is_silent()
	await last_heart_stops()
	await actual_checkpoint_reload()
	TimeService.reset()
	level.queue_free()
	await frames(2)
	print("DEATH_CHOICE_VERIFIED failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
