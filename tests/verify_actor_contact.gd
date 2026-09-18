extends Node
## Run with --headless --fixed-fps 60 tests/verify_actor_contact.tscn.
## Exercise both movers: a player hitting an enemy and an enemy hitting a player.

const ENEMIES := ["guard", "gunner", "warden", "robot", "guardian", "business_boss"]
var failures := 0


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func stop_updates(node: Node) -> void:
	# Keep physics bodies registered while this test drives their movement.
	node.set_physics_process(false)
	node.set_process(false)
	for child in node.get_children():
		stop_updates(child)


func draw_depth(item: CanvasItem) -> int:
	var depth := item.z_index
	if item.z_as_relative and item.get_parent() is CanvasItem:
		depth += draw_depth(item.get_parent())
	return depth


func verify_level_layers(path: String) -> void:
	var level := (load(path) as PackedScene).instantiate()
	var player_sprite := level.get_node("Entities/Player/Sprite") as CanvasItem
	var depth := draw_depth(player_sprite)
	for guide in level.get_node("Tutorial").get_children():
		check(draw_depth(guide) < depth, "%s: guide covers player" % path)
	for body in level.find_children("*", "CharacterBody2D", true, false):
		if body.has_node("Sprite"):
			check(draw_depth(body.get_node("Sprite")) == depth,
				"%s: %s draws on a different actor layer" % [path, body.name])
	level.free()


func verify_contact(enemy_name: String) -> void:
	var player := preload("res://src/actors/player/player.tscn").instantiate() as Player
	var enemy := (load("res://src/actors/enemy/%s.tscn" % enemy_name) as PackedScene).instantiate() as CharacterBody2D
	add_child(player)
	add_child(enemy)
	if enemy is BusinessBoss:
		enemy.activate()
	stop_updates(player)
	stop_updates(enemy)
	for side in [-1.0, 1.0]:
		for enemy_moves in [false, true]:
			player.position = Vector2(600.0 - 220.0 * side, 600.0)
			enemy.position = Vector2(600.0, 600.0)
			player.velocity = Vector2.ZERO
			enemy.velocity = Vector2.ZERO
			await get_tree().physics_frame
			var mover: CharacterBody2D = enemy if enemy_moves else player
			var other: CharacterBody2D = player if enemy_moves else enemy
			var contacted := false
			for frame in 60:
				mover.velocity = Vector2((-side if enemy_moves else side) * 450.0, 0.0)
				mover.move_and_slide()
				for index in mover.get_slide_collision_count():
					contacted = contacted or mover.get_slide_collision(index).get_collider() == other
				await get_tree().physics_frame
			check(contacted, "%s: no contact, enemy_moves=%s side=%s" % [enemy_name, enemy_moves, side])
			check((enemy.position.x - player.position.x) * side > 0.0,
				"%s: actors passed through each other" % enemy_name)
	player.free()
	enemy.free()
	await get_tree().physics_frame


func _ready() -> void:
	TimeService.reset()
	verify_level_layers("res://src/levels/level_01/level_01.tscn")
	verify_level_layers("res://src/levels/level_02/level_02.tscn")
	for enemy_name in ENEMIES:
		await verify_contact(enemy_name)
	if failures == 0:
		print("ACTOR_CONTACT_VERIFIED: both levels, six enemy types, both movers and sides")
	get_tree().quit(0 if failures == 0 else 1)
