extends Node
## Soaks every production-layout enemy against a nearby invulnerable player.
# A valid post must begin grounded and must not let its owner walk into a pit.

const EXTENSION := "res://src/levels/level_01_production_extension.tscn"
const PLAYER := "res://src/actors/player/player.tscn"
const FALL_TOLERANCE := 170.0


func _ready() -> void:
	var extension := (load(EXTENSION) as PackedScene).instantiate()
	add_child(extension)
	var player := (load(PLAYER) as PackedScene).instantiate() as Player
	add_child(player)
	player.get_node(^"Camera2D").enabled = false
	player.health.max_health = 1.0e9
	player.health.current = 1.0e9
	await get_tree().physics_frame
	for _frame in range(20):
		await get_tree().physics_frame

	var enemies := get_tree().get_nodes_in_group(&"enemy")
	var posts := {}
	for enemy in enemies:
		posts[enemy.get_instance_id()] = enemy.global_position
		if not enemy.is_on_floor():
			push_error("%s did not settle on a floor at %s" % [enemy.name, enemy.position])
			get_tree().quit(1)
			return

	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		player.global_position = enemy.global_position + Vector2(280.0, -20.0)
		player.velocity = Vector2.ZERO
		for _frame in range(45):
			await get_tree().physics_frame
		if not is_instance_valid(enemy):
			continue
		var origin: Vector2 = posts[enemy.get_instance_id()]
		if enemy.global_position.y - origin.y > FALL_TOLERANCE:
			push_error("%s walked off its post: %s -> %s" % [
				enemy.name, origin, enemy.global_position,
			])
			get_tree().quit(1)
			return

	# No camera-width slice should open with a mob wall. Four is the ceiling and
	# only occurs where the optional shortcut crosses above the Long Way.
	var max_in_slice := 0
	for pivot in enemies:
		if not is_instance_valid(pivot):
			continue
		var count := 0
		for other in enemies:
			if is_instance_valid(other) and absf(other.global_position.x - pivot.global_position.x) <= 400.0:
				count += 1
		max_in_slice = maxi(max_in_slice, count)
	assert(max_in_slice <= 4)
	print("PRODUCTION_ENEMY_FOOTING_OK units=%d max_per_camera=%d" % [
		enemies.size(), max_in_slice,
	])
	get_tree().quit()
