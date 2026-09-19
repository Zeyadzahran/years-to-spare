extends Node
## Run with --headless --fixed-fps 60 tests/verify_enemy_chase.tscn.

var failures := 0
var player: Player
var enemy: Enemy
var fixtures: Node2D


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func terrain(center: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = center
	fixtures.add_child(body)
	return body


func setup(enemy_name: String, floor_width := 1400.0) -> void:
	TimeService.reset()
	fixtures = Node2D.new()
	add_child(fixtures)
	terrain(Vector2(400, 620), Vector2(floor_width, 40))
	player = preload("res://src/actors/player/player.tscn").instantiate() as Player
	player.position = Vector2(1020, 600)
	fixtures.add_child(player)
	player.set_physics_process(false)
	player.states.set_physics_process(false)
	player.health.max_health = 10000.0
	player.health.current = 10000.0
	enemy = (load("res://src/actors/enemy/%s.tscn" % enemy_name) as PackedScene).instantiate() as Enemy
	enemy.position = Vector2(600, 600)
	fixtures.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.target = player
	enemy.state = &"Chase"
	await tick(2)


func tick(count: int) -> void:
	for frame in count:
		await get_tree().physics_frame
		enemy._physics_process(1.0 / 60.0)


func cleanup() -> void:
	TimeService.reset()
	fixtures.free()
	await get_tree().physics_frame


func verify_raised_player(enemy_name: String) -> void:
	await setup(enemy_name)
	# Keep the platform within detection height but outside attack height.
	terrain(Vector2(820, 460), Vector2(140, 20))
	player.position = Vector2(820, 450)
	await tick(90)
	check(enemy.sprite.animation == &"idle" and is_zero_approx(enemy.velocity.x),
		"%s runs toward an unreachable platform" % enemy_name)
	check(enemy.position.x < 650.0, "%s chased underneath the raised player" % enemy_name)
	var saved := enemy.rewind_capture()
	# Returning to the same floor must resume pursuit, then land an attack.
	player.position = Vector2(730, 600)
	await tick(120)
	check(player.health.current < player.health.max_health, "%s did not resume combat" % enemy_name)
	player.position = Vector2(820, 450)
	enemy.rewind_apply(saved)
	enemy.set_physics_process(false)
	await tick(10)
	check(enemy.sprite.animation == &"idle", "%s resumed running after restoring a blocked chase" % enemy_name)
	await cleanup()


func verify_obstacle(enemy_name: String, height: float) -> void:
	await setup(enemy_name)
	# The low version leaves eye-level visibility clear, but blocks the body.
	var wall := terrain(Vector2(680, 600 - height * 0.5), Vector2(40, height))
	player.position = Vector2(1020, 600)
	await tick(150)
	check(enemy.sprite.animation == &"idle" and is_zero_approx(enemy.velocity.x),
		"%s runs into a %s-pixel obstacle" % [enemy_name, height])
	check(enemy.position.x < 643.0, "%s crossed solid terrain" % enemy_name)
	var stopped_x := enemy.position.x
	wall.free()
	await tick(20)
	check(enemy.position.x > stopped_x + 10.0 and enemy.state in [&"Chase", &"Attack"],
		"%s did not resume after the obstacle was removed" % enemy_name)
	await cleanup()


func verify_ledge(enemy_name: String) -> void:
	await setup(enemy_name, 500.0)
	# Same height with a gap between the two supporting platforms.
	terrain(Vector2(980, 620), Vector2(180, 40))
	player.position = Vector2(990, 600)
	await tick(150)
	check(enemy.position.y < 601.0, "%s fell from its ledge" % enemy_name)
	check(enemy.sprite.animation == &"idle" and is_zero_approx(enemy.velocity.x),
		"%s runs in place at a ledge" % enemy_name)
	player.position = Vector2(480, 600)
	await tick(120)
	check(player.health.current < player.health.max_health, "%s did not turn and re-engage" % enemy_name)
	await cleanup()


func _ready() -> void:
	for enemy_name in ["guard", "gunner", "warden"]:
		await verify_raised_player(enemy_name)
		await verify_obstacle(enemy_name, 40.0)
		await verify_obstacle(enemy_name, 220.0)
		await verify_ledge(enemy_name)
	if failures == 0:
		print("ENEMY_CHASE_VERIFIED: raised platforms, low crates, walls, ledges, resumed combat and restored chase")
	get_tree().quit(0 if failures == 0 else 1)
