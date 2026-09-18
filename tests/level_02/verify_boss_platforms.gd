extends Node
## Walk and jump the authored moving-platform route without time powers.

const MAP := preload("res://src/levels/level_02/level_02.tscn")
const ROUTE := ["StepOne", "StepTwo", "StepThree", "ArenaPlatform"]
var failures := 0
var player: Player
var arena: Node2D

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func steer(target_x: float) -> void:
	var direction := clampf((target_x - player.global_position.x) / 45.0, -1.0, 1.0)
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	if absf(direction) > 0.05:
		Input.action_press(&"move_right" if direction > 0.0 else &"move_left", absf(direction))

func standing_on(platform: MovingIndustrialPlatform) -> bool:
	if not player.is_on_floor():
		return false
	for i in player.get_slide_collision_count():
		var contact := player.get_slide_collision(i)
		if contact.get_collider() == platform and contact.get_normal().y < -0.5:
			return true
	return false

func climb(age: float) -> void:
	GameState.clear_run_progress()
	var level := MAP.instantiate()
	add_child(level)
	player = level.get_node("Entities/Player")
	arena = level.get_node("World/BossArena")
	level.get_node("Enemies").process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("World/Hazards").process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = arena.to_global(Vector2(241, 640))
	player.age.set_to(age)
	await frames(5)
	var source: MovingIndustrialPlatform = null
	for platform_name in ROUTE:
		var target: MovingIndustrialPlatform = arena.get_node("Platforms/" + platform_name)
		var launch_x := target.global_position.x if source == null else source.global_position.x + source.width_tiles * 32.0 - 24.0
		var landing_x := target.global_position.x if source == null else target.global_position.x - target.width_tiles * 32.0 + 32.0
		var launched := false
		var landed := false
		for tick in 900:
			steer(landing_x if launched else launch_x)
			if not launched and player.is_on_floor() and absf(player.global_position.x - launch_x) < 12.0:
				# Wait for the next lift to descend into a comfortable jump range.
				var rise := player.global_position.y - target.global_position.y
				if rise < 140.0 and target._direction < 0.0:
					Input.action_press(&"jump")
					launched = true
					await frames(2)
					Input.action_release(&"jump")
			await frames(1)
			if launched and standing_on(target):
				landed = true
				break
			if launched and player.is_on_floor() and not standing_on(source):
				break
		check(landed, "Age %s could not jump to %s; player=%s target=%s" % [age, platform_name, player.global_position, target.global_position])
		if not landed:
			break
		print("BOSS_PLATFORMS age=%s landed=%s" % [age, platform_name])
		source = target
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	Input.action_release(&"jump")
	TimeService.reset()
	level.queue_free()
	await frames(2)

func _ready() -> void:
	await climb(14.0)
	await climb(59.0)
	print("BOSS_PLATFORMS_VERIFIED failures=%d" % failures)
	get_tree().quit(1 if failures else 0)
