extends "res://tests/level_02/verify_business_boss.gd"

# Observe the normal restart path without reloading the test runner itself.
class RetryLevel extends Level:
	var reload_count := 0
	func reload() -> void:
		reload_count += 1
		TimeService.reset()

func fresh(start_encounter := true) -> void:
	TimeService.reset()
	if is_instance_valid(level):
		level.queue_free()
	await frames(2)
	GameState.clear_run_progress()
	level = MAP.instantiate()
	level.set_script(RetryLevel)
	level.level_id = &"phase_2"
	level.debug_spawn_path = NodePath()
	add_child(level)
	get_tree().current_scene = self
	player = level.get_node("Entities/Player")
	arena = level.get_node("World/BossArena")
	boss = arena.boss
	level.get_node("Enemies").process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("World/Hazards").process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = arena.to_global(Vector2(150,640))
	if start_encounter:
		arena.prepare_gate_entry(player)
		# The entrance dialogue now locks the player until combat begins.
		var skip := InputEventKey.new()
		skip.keycode = KEY_ENTER
		skip.physical_keycode = KEY_ENTER
		skip.pressed = true
		Input.parse_input_event(skip)
		skip = skip.duplicate()
		skip.pressed = false
		Input.parse_input_event(skip)
		await wait_stage(arena.Stage.FIGHTING)
	await frames(5)

## A death with a heart to spare commits itself once the rewind window has
## passed; the last one stops on the Game Over screen, where Enter restarts.
func confirm_death() -> void:
	var last := GameState.hearts <= 1 or player.age.age >= player.age.death_age
	var hearts_before := GameState.hearts
	for i in 180:
		await frames(1)
		if last and player.has_node("GameOver"):
			break
		if not last and GameState.hearts < hearts_before:
			break
	if not last:
		check(not get_tree().paused and not player.has_node("GameOver"), "A spare heart still stopped for a choice")
		await frames(1)
		return
	check(get_tree().paused and player.has_node("GameOver"), "Last heart did not stop on Game Over")
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	await frames(1)
	check(not get_tree().paused, "Restart left the game paused")

func die_and_respawn() -> void:
	player.health.kill(boss)
	await confirm_death()
	check(player.health.is_alive(), "Remaining heart failed to respawn the player")

func retry_progress() -> void:
	await fresh()
	boss.receive_player_hit(170.0, player)
	player.age.set_to(30.0)
	var instance_id := boss.get_instance_id()
	var hp := boss.health.current
	var old_round := BusinessBoss.LASER_SCENE.instantiate() as BusinessLaser
	add_child(old_round)
	old_round.global_position = arena.to_global(Vector2(700,100))
	old_round.setup(Vector2.ZERO, 18.0, boss)
	await die_and_respawn()
	check(GameState.hearts == 2 and level.reload_count == 0, "First heart reloaded the room")
	check(boss.get_instance_id() == instance_id and boss.health.current == hp, "First heart reset boss health")
	check(player.age.age == 30.0 and player.health.current == player.health.max_health, "Retry lost age or did not heal player")
	check(player.global_position.distance_to(boss.global_position) > 300.0 and player.global_position.y < 641.0, "Retry did not choose a safe arena floor")
	check(TimeService._now < 0.1, "Retry kept history from the paid death")
	check(not is_instance_valid(old_round) or old_round.is_queued_for_deletion(), "Retry kept a projectile from the previous life")
	TimeService.mode = TimeService.Mode.REWINDING
	await frames(8)
	TimeService.mode = TimeService.Mode.NORMAL
	check(player.health.is_alive() and GameState.hearts == 2, "Rewind crossed the spent-heart boundary")
	# Die during a wave after damaging one trooper and killing another.
	boss.receive_player_hit(300.0, player)
	await wait_stage(arena.Stage.WAVE)
	await frames(40)
	var survivor: Enemy = arena._reinforcements[0]
	survivor.health.take_damage(34.0, player)
	arena._reinforcements[1].health.kill(player)
	var survivor_hp := survivor.health.current
	var remaining: int = arena._living_reinforcements()
	var wave_hp := boss.health.current
	await die_and_respawn()
	check(GameState.hearts == 1 and level.reload_count == 0, "Second heart reloaded the room")
	check(boss.health.current == wave_hp and arena._phase_breaks == 1, "Second heart reset boss phase progress")
	check(arena.stage == arena.Stage.WAVE and arena._living_reinforcements() == remaining, "Retry restarted the reinforcement wave")
	check(is_instance_valid(survivor) and survivor.health.current == survivor_hp, "Retry healed a surviving reinforcement")
	player.health.kill(boss)
	await confirm_death()
	check(level.reload_count == 1 and GameState.hearts == GameState.MAX_HEARTS, "Third heart did not use the full restart path")
	print("BOSS_RETRIES first/second heart: same boss HP, phase, wave, age; third heart: full restart")

func restart_boundaries() -> void:
	await fresh(false)
	player.health.kill()
	await confirm_death()
	check(level.reload_count == 1 and GameState.hearts == 2, "Death outside the arena stopped using checkpoint reload")
	await fresh()
	player.age.spend(player.age.death_age)
	await confirm_death()
	check(level.reload_count == 1 and GameState.hearts == GameState.MAX_HEARTS and GameState.run_age < 0.0, "Old age did not reset the run")
	print("BOSS_RETRIES boundaries: ordinary checkpoint death and old age unchanged")

func _ready() -> void:
	await retry_progress()
	await restart_boundaries()
	print("BOSS_RETRIES_VERIFIED failures=%d" % failures)
	TimeService.reset()
	level.queue_free()
	await frames(2)
	get_tree().quit(1 if failures else 0)
