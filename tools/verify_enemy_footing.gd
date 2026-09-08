extends Node
## Soak test for enemy footing. Drops the boy in front of each ledge-bound
## trooper, lets the chase run, and fails if any of them walks off its perch.
##
## This is the counterpart to the static placement audits: those prove a unit
## STARTS on solid ground, this proves the AI keeps it there once it moves.

const LEVEL := "res://src/levels/level_01.tscn"
const SECONDS := 1.5
## A unit that has dropped further than this below its post has left it.
const FALL_TOLERANCE := 170.0


func _ready() -> void:
	var level := (load(LEVEL) as PackedScene).instantiate()
	add_child(level)
	await get_tree().physics_frame

	var player := get_tree().get_first_node_in_group(&"player") as Player
	# A death here would run Level._on_player_died -> reload_current_scene(),
	# which reloads THIS test scene and restarts the run forever. The boy is
	# only bait for the chase, so give him a bar nothing can empty.
	player.health.max_health = 1.0e9
	player.health.current = 1.0e9
	# Only the troops posted on narrow ledges can fall off one; testing the units
	# standing on open ground would triple the runtime to prove nothing.
	var watched: Array = []
	for enemy in get_tree().get_nodes_in_group(&"enemy"):
		var n := String(enemy.name)
		if n.begins_with("Long") or n.begins_with("Yard") or n.begins_with("Firing") \
				or n.begins_with("LowRoad") or n.begins_with("WardenGunner"):
			watched.append({"node": enemy, "name": enemy.name, "y": enemy.global_position.y})

	var failures := 0
	for entry: Dictionary in watched:
		var enemy: Node2D = entry["node"]
		if not is_instance_valid(enemy):
			continue
		# Stand the boy just inside detection range so the unit commits to a
		# chase, and out of baton reach so the fight does not end the test.
		player.global_position = enemy.global_position + Vector2(300.0, -40.0)
		player.velocity = Vector2.ZERO
		var frames := int(SECONDS * 60.0)
		for _f in frames:
			await get_tree().physics_frame
			if not is_instance_valid(enemy):
				break
		if not is_instance_valid(enemy):
			continue
		var drop: float = enemy.global_position.y - float(entry["y"])
		if drop > FALL_TOLERANCE:
			failures += 1
			push_error("%s fell %.0fpx off its post." % [entry["name"], drop])

	if failures == 0:
		print("ENEMY_FOOTING_OK units=%d" % watched.size())
		get_tree().quit(0)
	else:
		push_error("ENEMY_FOOTING_FAILED units=%d" % failures)
		get_tree().quit(1)
