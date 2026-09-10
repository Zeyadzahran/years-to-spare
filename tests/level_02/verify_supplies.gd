extends Node
## Exercise real chest overlaps and the player's health-to-HUD signal path.
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func settle() -> void:
	for i in 4:
		await get_tree().physics_frame

func _ready() -> void:
	var player := preload("res://src/actors/player/player.tscn").instantiate()
	# Hold the player still without removing its body from overlap detection.
	player.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	player.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(player)
	var hud := preload("res://src/ui/hud.tscn").instantiate()
	add_child(hud)
	var map := preload("res://src/levels/level_02/level_02.tscn").instantiate()
	var supplies := map.get_node("World/Supplies")
	var initial_hearts := GameState.hearts
	for chest in supplies.get_children():
		chest.owner = null
		supplies.remove_child(chest)
		add_child(chest)
		player.global_position = chest.global_position
		player.health.current = 100.0
		await settle()
		check(not chest.opened, "%s wasted at full health" % chest.name)
		player.health.current = 40.0
		await settle()
		check(player.health.current == 90.0, "%s did not heal on contact" % chest.name)
		check(hud.health_value.text == "90", "%s did not update HUD" % chest.name)
		check(chest.opened and chest.get_node("Art").frame == 3, "%s did not open" % chest.name)
		print("CHEST_CONTACT %s health=%s HUD=%s" % [chest.name, player.health.current, hud.health_value.text])
		player.health.current = 40.0
		await settle()
		check(player.health.current == 40.0, "%s healed twice" % chest.name)
		chest.queue_free()
		await get_tree().process_frame
	check(GameState.hearts == initial_hearts, "Health chest unexpectedly changed lives")
	map.free()
	hud.queue_free()
	player.queue_free()
	await get_tree().process_frame
	print("LEVEL_02_SUPPLIES_VERIFIED failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
