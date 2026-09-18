extends Node
## The fall lesson at the start of Level 2: the hole cannot be jumped on a
## fresh run, the first fall stops the world on the card, L rewinds, the
## ledges slide out, and from then on the hole is an ordinary pit.
## Run with --headless --fixed-fps 60.

const MAP := preload("res://src/levels/level_02/level_02.tscn")

var failures := 0
var level: Level
var player: Player
var _deaths := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)

## The street with its pit live: hazards on, guards off.
func fresh() -> void:
	TimeService.reset()
	if is_instance_valid(level):
		level.queue_free()
		await frames(2)
	level = MAP.instantiate()
	level.debug_spawn_path = NodePath()
	add_child(level)
	get_tree().current_scene = self
	player = level.get_node("Entities/Player")
	level.get_node("Enemies").process_mode = Node.PROCESS_MODE_DISABLED
	await frames(3)

func lesson() -> Node: return level.get_node("Tutorial/RewindLesson")
func left() -> Node2D: return level.get_node("World/Platforms/LessonLeft")
func right() -> Node2D: return level.get_node("World/Platforms/LessonRight")

func place(at: Vector2) -> void:
	Input.action_release("move_right")
	Input.action_release("jump")
	player.global_position = at
	player.velocity = Vector2.ZERO
	await frames(12)

## A running jump from `takeoff_x`; true if he lands on the floor past `end_x`.
func jump_across(start: Vector2, takeoff_x: float, end_x: float) -> bool:
	await place(start)
	Input.action_press("move_right")
	for i in 120:
		await frames(1)
		if player.position.x >= takeoff_x:
			break
	Input.action_press("jump")
	await frames(2)
	Input.action_release("jump")
	var landed := false
	for i in 100:
		await frames(1)
		if player.position.x > end_x and player.is_on_floor():
			landed = true
			break
		if player.position.y > 900 or player.is_down():
			break
	Input.action_release("move_right")
	return landed

func _ready() -> void:
	await uncrossable()
	await the_lesson()
	await afterwards()
	print("REWIND_LESSON_VERIFIED failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func uncrossable() -> void:
	GameState.clear_run_progress()
	await fresh()
	check(left().position.y > 640 and right().position.y > 640, "Ledges not tucked away on a fresh run")
	check(level.get_node("Tutorial/Jump").visible, "No sign asks him to jump the hole")
	check(not await jump_across(Vector2(1200, 640), 1395, 1925), "The street hole could be jumped from the ground")
	await fresh()
	check(not await jump_across(Vector2(1150, 423), 1360, 1925), "The street hole could be jumped from the cache ledge")
	print("REWIND_LESSON the hole cannot be jumped")

func the_lesson() -> void:
	GameState.clear_run_progress()
	await fresh()
	await place(Vector2(1200, 640))
	# Practice just before it put Rewind on cooldown; the lesson forgives it.
	player.powers._cooldowns[GameState.ABILITY_REWIND] = 5.0
	var hearts := GameState.hearts
	var age := player.age.age
	Input.action_press("move_right")
	var paused := false
	for i in 300:
		await frames(1)
		if get_tree().paused:
			paused = true
			break
	Input.action_release("move_right")
	check(paused, "The first fall did not stop the world")
	check(player.is_down(), "World stopped before he was down")
	check(lesson().get_node("Card").visible, "Card not shown")
	check(GameState.rewind_lesson_done, "Lesson not marked as given")
	check(is_zero_approx(player.powers.cooldown_left(GameState.ABILITY_REWIND)), "Lesson left Rewind on cooldown")
	check(GameState.hearts == hearts, "Lesson cost a heart")
	press_key(KEY_ESCAPE)
	check(get_tree().paused, "Escape got past the card")
	press_key(KEY_L)
	await frames(1)
	check(not get_tree().paused and not lesson().get_node("Card").visible, "L did not lift the pause")
	check(player.powers.is_casting(GameState.ABILITY_REWIND) or player.powers.is_winding_up(), "L did not cast Rewind")
	var frozen := false
	var enemies_off := false
	for i in 400:
		await frames(1)
		if player.process_mode == Node.PROCESS_MODE_DISABLED:
			frozen = true
			if level.get_node("Enemies").process_mode == Node.PROCESS_MODE_DISABLED:
				enemies_off = true
		if frozen and player.process_mode == Node.PROCESS_MODE_INHERIT:
			break
	check(frozen and enemies_off, "He was not held still (with the guards) while the ledges moved")
	check(player.process_mode == Node.PROCESS_MODE_INHERIT, "He was not handed back")
	check(player.health.is_alive() and not player.is_down(), "Rewind did not revive him")
	check(is_equal_approx(player.age.age, age), "The lesson aged him: %s -> %s" % [age, player.age.age])
	check(GameState.hearts == hearts, "The lesson spent a heart")
	check(left().position.is_equal_approx(lesson().left_closed) and right().position.is_equal_approx(lesson().right_closed), "Ledges did not slide out: %s %s" % [left().position, right().position])
	var camera := player.get_node("Camera2D") as Camera2D
	check(camera.offset.is_zero_approx(), "Camera did not look back: %s" % camera.offset)
	check(level.get_node("Enemies").process_mode == Node.PROCESS_MODE_INHERIT, "Guards were not handed back")
	check(await jump_across(Vector2(1300, 640), 1585, 1810), "The closed hole could not be jumped")
	print("REWIND_LESSON first fall stops on the card, L revives, ledges slide out")

func afterwards() -> void:
	# A retry finds the ledges out already, and a fall is just a fall.
	GameState.set_checkpoint(&"L2MachineYard", Vector2(1340, 652), player.age.age)
	await fresh()
	check(left().position.is_equal_approx(lesson().left_closed) and right().position.is_equal_approx(lesson().right_closed), "Retry did not find the ledges out")
	EventBus.player_died.disconnect(level._on_player_died)
	EventBus.player_died.connect(_count_death)
	var hearts := GameState.hearts
	await place(Vector2(1700, 640))
	var camera := player.get_node("Camera2D") as Camera2D
	var floor_before := camera.limit_bottom
	var paused := false
	var view_bottom := INF
	for i in 200:
		await frames(1)
		if get_tree().paused:
			paused = true
		if player.is_down() and view_bottom == INF and i > 60:
			view_bottom = (get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect().size).y
		if _deaths > 0:
			break
	# The camera stopped following: the view's floor stayed put while he fell
	# out of it.
	var view_bottom_now := (get_viewport().get_canvas_transform().affine_inverse() * get_viewport().get_visible_rect().size).y
	check(view_bottom != INF and absf(view_bottom_now - view_bottom) < 2.0, "Camera followed him into the void: %s -> %s" % [view_bottom, view_bottom_now])
	check(player.global_position.y > view_bottom_now + 40.0, "He did not fall out of the frame")
	check(camera.limit_bottom < floor_before, "Camera floor was not held for the fall")
	EventBus.player_died.disconnect(_count_death)
	check(not paused, "A later fall stopped the world again")
	check(_deaths == 1, "A later fall did not commit as a plain death")
	check(GameState.hearts == hearts, "Death committed the heart itself (the level does that)")
	print("REWIND_LESSON afterwards the hole is an ordinary pit")


func _count_death(_old_age: bool) -> void:
	_deaths += 1
