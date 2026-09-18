extends Node
## A frozen Guardian takes a fraction of a swing. Two five-second stops used
## to be the whole fight; a stop is now worth about a quarter of the bar, and
## the window after the stomp stays the strongest hit.

const LEVEL_SCENE := preload("res://src/levels/level_01/level_01.tscn")

var failures := 0


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _ready() -> void:
	GameState.clear_run_progress()
	TimeService.reset()
	var level := LEVEL_SCENE.instantiate() as Level
	add_child(level)
	await frames(2)
	var arena := level.get_node(^"World/BossArena") as BossArena
	var player := level.get_node(^"Entities/Player") as Player
	var boss := arena.boss
	var swing := player.attack_damage
	var full := boss.health.max_health

	# Frozen: the swing is cut to FROZEN, whether or not the stomp had just
	# left him open.
	TimeService.mode = TimeService.Mode.STOPPED
	await frames(1)
	boss.receive_player_hit(swing, player)
	check(is_equal_approx(full - boss.health.current, swing * Guardian.FROZEN_DAMAGE_MULTIPLIER), "Frozen hit was not cut to the frozen rate")
	var frozen_hit := full - boss.health.current
	boss.set("_vulnerable", true)
	boss.receive_player_hit(swing, player)
	check(is_equal_approx(full - boss.health.current, frozen_hit * 2.0), "Vulnerable window kept its rate through a stop")
	boss.set("_vulnerable", false)
	# Ten swings fit in one five-second stop; two stops must leave him standing.
	boss.health.heal(full)
	for i in 20:
		boss.receive_player_hit(swing, player)
	check(boss.health.is_alive() and boss.health.current > full * 0.4, "Two stops still took the whole bar")
	TimeService.mode = TimeService.Mode.NORMAL
	await frames(1)

	# Moving: normal and open-window rates are as before, and the window is
	# still the strongest hit there is.
	boss.health.heal(full)
	boss.receive_player_hit(swing, player)
	check(is_equal_approx(full - boss.health.current, swing * Guardian.NORMAL_DAMAGE_MULTIPLIER), "Normal hit changed rate")
	boss.health.heal(full)
	boss.set("_vulnerable", true)
	boss.receive_player_hit(swing, player)
	check(is_equal_approx(full - boss.health.current, swing * Guardian.VULNERABLE_DAMAGE_MULTIPLIER), "Open-window hit changed rate")
	check(Guardian.VULNERABLE_DAMAGE_MULTIPLIER > Guardian.NORMAL_DAMAGE_MULTIPLIER and Guardian.NORMAL_DAMAGE_MULTIPLIER > Guardian.FROZEN_DAMAGE_MULTIPLIER, "Rates are not ordered window > moving > frozen")
	boss.set("_vulnerable", false)

	print("BOSS_STOP_DAMAGE_VERIFIED failures=%d" % failures)
	TimeService.reset()
	level.queue_free()
	await frames(2)
	get_tree().quit(1 if failures else 0)
