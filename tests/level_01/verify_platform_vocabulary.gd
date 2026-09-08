extends Node


func _ready() -> void:
	var player := (load("res://src/actors/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(player)
	assert(is_equal_approx(player.jump_velocity, -900.0))
	var apex := player.jump_velocity * player.jump_velocity / (2.0 * player.gravity)
	var young_reach := player.speed * (-2.0 * player.jump_velocity / player.gravity)
	var old_reach := player.speed * Player.ELDER_SPEED * (-2.0 * player.jump_velocity / player.gravity)
	assert(apex > 150.0 and apex < 160.0)
	assert(young_reach > 300.0 and young_reach < 315.0)
	assert(old_reach > 250.0 and old_reach < 260.0)
	player.queue_free()

	var linear := (load("res://src/world/platforms/moving_platform.tscn") as PackedScene).instantiate() as MovingPlatform
	linear.travel = Vector2(480, 0)
	linear.speed = 180.0
	add_child(linear)
	var orbit := (load("res://src/world/platforms/moving_platform.tscn") as PackedScene).instantiate() as MovingPlatform
	orbit.motion_mode = MovingPlatform.MotionMode.ORBIT
	orbit.orbit_radii = Vector2(220, 110)
	add_child(orbit)
	var blink := (load("res://src/world/platforms/blink_platform.tscn") as PackedScene).instantiate() as BlinkPlatform
	blink.visible_time = 0.08
	blink.hidden_time = 0.08
	add_child(blink)

	TimeService.mode = TimeService.Mode.NORMAL
	var linear_start := linear.position
	var orbit_start := orbit.position
	for _frame in range(5):
		await get_tree().physics_frame
	assert(not linear.position.is_equal_approx(linear_start))
	assert(not orbit.position.is_equal_approx(orbit_start))

	var linear_frozen := linear.position
	var orbit_frozen := orbit.position
	var blink_frozen := blink.is_active()
	TimeService.mode = TimeService.Mode.STOPPED
	for _frame in range(12):
		await get_tree().physics_frame
	assert(linear.position.is_equal_approx(linear_frozen))
	assert(orbit.position.is_equal_approx(orbit_frozen))
	assert(blink.is_active() == blink_frozen)
	TimeService.reset()

	print("PLATFORM_VOCABULARY_OK apex=%.1f young_reach=%.1f old_reach=%.1f" % [
		apex, young_reach, old_reach,
	])
	get_tree().quit()
