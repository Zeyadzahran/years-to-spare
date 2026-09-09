extends Node
## The fast transfer must form a route within one real five-second time stop.

const FIXTURE = preload("res://tests/level_01/fixture.gd")
const PLAYER = preload("res://src/actors/player/player.tscn")
var section: Node2D
var player: Player
var failed := false


func _ready() -> void:
	for age in [23.0, 53.0]:
		await _setup(age)
		var first := section.get_node(^"Platforms/TransferIn") as MovingPlatform
		var rest := section.get_node(^"Platforms/TransferRest") as Node2D
		var second := section.get_node(^"Platforms/TransferOut") as MovingPlatform
		_check(first.speed >= 850 and second.speed >= 850, "Transfer speed regressed")
		_check(absf(first.travel.length() / first.speed - second.travel.length() / second.speed) < 0.005,
			"Transfer cycles no longer align")
		var apex := player.jump_velocity * player.jump_velocity / (2 * player.gravity)
		var low_stop: float = first.get("_origin").y + 1 + first.travel.y * 0.25
		var high_stop: float = first.get("_origin").y + 1 + first.travel.y * 0.98
		_check(low_stop - _surface(rest) > apex, "An early stop should not reach the rest")
		_check(119 - high_stop > apex, "A late stop should be too high to board")
		for _frame in range(120):
			if first.get("_direction") > 0 and first.get("_progress") >= 0.94:
				break
			await get_tree().physics_frame
		print("CAST phase=", first.get("_progress"))
		Input.action_press(&"time_stop")
		await get_tree().process_frame
		await get_tree().process_frame
		Input.action_release(&"time_stop")
		for _frame in range(45):
			await get_tree().physics_frame
			if TimeService.mode == TimeService.Mode.STOPPED:
				break
		await get_tree().physics_frame
		await get_tree().physics_frame
		_check(TimeService.mode == TimeService.Mode.STOPPED, "Ability did not engage")
		_check(is_equal_approx(player.age.age, age + 3), "Cast did not cost three years")
		print("FROZEN first=",first.position," second=",second.position)
		var start_time := player.powers.time_left
		await _jump(first, first.position.x - first.size.x * 0.5 + 20)
		await _walk(first.position.x + first.size.x * 0.5 - 24)
		await _jump(rest, rest.position.x)
		await _walk(rest.position.x + rest.get("size").x * 0.5 - 24)
		await _jump(second, second.position.x - second.size.x * 0.5 + 20)
		await _walk(second.position.x + second.size.x * 0.5 - 24)
		await _jump(null, 16050)
		_check(TimeService.mode == TimeService.Mode.STOPPED, "Route exceeded one time stop")
		_check(player.health.current == 100, "Route touched the spikes")
		print("TRANSFER_CROSS age=",age," cost=3 duration=",start_time-player.powers.time_left)
		await _cleanup()
	await _check_spikes()
	if not failed:
		print("TRANSFER_TIMING_OK ages=23,53 one_cast=true spikes_lethal_while_frozen=true")
	get_tree().quit(1 if failed else 0)


func _setup(age: float) -> void:
	GameState.start_new_run()
	TimeService.reset()
	section = FIXTURE.late_sections()
	section.get_node(^"Enemies").free()
	add_child(section)
	player = PLAYER.instantiate() as Player
	player.position = Vector2(15096, 117)
	add_child(player)
	player.get_node(^"Camera2D").enabled = false
	player.age.set_to(age)
	for _frame in range(12):
		await get_tree().physics_frame


func _surface(deck: Node2D) -> float:
	var shape := deck.get_node(^"Shape") as CollisionShape2D
	return shape.global_position.y - (shape.shape as RectangleShape2D).size.y * 0.5


func _steer(x: float) -> void:
	Input.action_release(&"move_left")
	Input.action_release(&"move_right")
	if player.position.x < x - 5:
		Input.action_press(&"move_right")
	elif player.position.x > x + 5:
		Input.action_press(&"move_left")


func _walk(x: float) -> void:
	for _frame in range(90):
		_steer(x)
		await get_tree().physics_frame
		if absf(player.position.x - x) <= 6:
			_steer(player.position.x)
			return
	_check(false, "Cannot walk to %.1f, at %s" % [x,player.position])


func _jump(deck: Node2D, x: float) -> void:
	var y := _surface(deck) if deck != null else 119.0
	Input.action_press(&"jump")
	for frame in range(90):
		_steer(x)
		await get_tree().physics_frame
		Input.action_release(&"jump")
		if frame > 8 and player.is_on_floor() and absf(player.position.y - y) < 5 \
				and absf(player.position.x - x) < 30:
			_steer(player.position.x)
			return
	_check(false, "Cannot jump to %s x=%.1f y=%.1f; player=%s" % [
		deck.name if deck else &"bank", x,y,player.position])


func _check_spikes() -> void:
	# Physical overlaps cover both edges and the joints between spike strips.
	for x in [15130, 15298, 15459, 15620, 15781, 15950]:
		await _setup(23)
		TimeService.mode = TimeService.Mode.STOPPED
		player.position = Vector2(x, 300)
		player.velocity = Vector2.ZERO
		for _frame in range(10):
			await get_tree().physics_frame
		_check(not player.health.is_alive(), "Safe hole in spike floor at x=%d" % x)
		await _cleanup()


func _cleanup() -> void:
	_steer(player.position.x)
	Input.action_release(&"jump")
	player.powers.cancel()
	TimeService.reset()
	player.free()
	section.free()
	await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
