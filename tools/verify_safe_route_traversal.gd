extends Node
## Uses the real Player state machine at age 59 to cross every one-tile seam
## on the Long Way. No time power is activated in this test.

const EXTENSION := "res://src/levels/level_01_production_extension.tscn"
const PLAYER := "res://src/actors/player/player.tscn"
const CELL := 120.0
const TERRAIN_Y := -1.0

const GAPS := [
	# left edge cell, right start cell, left top, right top
	[174, 176, 1, 2],
	[182, 184, 2, 3],
	[190, 192, 3, 4],
	[198, 200, 4, 5],
	[206, 208, 5, 4],
	[214, 216, 4, 3],
	[222, 224, 3, 2],
	[230, 232, 2, 1],
	[294, 296, 4, 3],
]


func _ready() -> void:
	var extension := (load(EXTENSION) as PackedScene).instantiate()
	add_child(extension)
	# This gate measures geometry only. Combat gets a separate footing/pressure
	# audit so a patrol body cannot be mistaken for an unreachable jump.
	extension.get_node(^"Enemies").free()
	await get_tree().physics_frame
	for gap: Array in GAPS:
		if not await _cross_gap(gap[0], gap[1], gap[2], gap[3]):
			get_tree().quit(1)
			return
	assert(TimeService.mode == TimeService.Mode.NORMAL)
	print("SAFE_ROUTE_TRAVERSAL_OK gaps=%d age=59 time_stops=0" % GAPS.size())
	get_tree().quit()


func _cross_gap(left_cell: int, right_cell: int, left_top: int, right_top: int) -> bool:
	var player := (load(PLAYER) as PackedScene).instantiate() as Player
	player.position = Vector2((left_cell + 1) * CELL - 190.0,
		left_top * CELL + TERRAIN_Y - 2.0)
	add_child(player)
	player.get_node(^"Camera2D").enabled = false
	player.health.max_health = 1.0e9
	player.health.current = 1.0e9
	player.age.set_to(59.0)
	for _frame in range(8):
		await get_tree().physics_frame

	var edge_x := (left_cell + 1) * CELL
	var target_x := right_cell * CELL + 125.0
	var launch_margin := 15.0 if right_top < left_top else 92.0
	Input.action_press(&"move_right")
	var jumped := false
	var landed := false
	for _frame in range(150):
		if not jumped and player.position.x >= edge_x - launch_margin:
			Input.action_press(&"jump")
			jumped = true
		elif jumped:
			Input.action_release(&"jump")
		await get_tree().physics_frame
		if player.position.x >= target_x and player.is_on_floor():
			landed = true
			break
		if player.position.y > right_top * CELL + TERRAIN_Y + 360.0:
			break
	Input.action_release(&"move_right")
	Input.action_release(&"jump")
	if not landed:
		push_error("Age-59 route failed at cells %d -> %d; player=%s" % [
			left_cell, right_cell, player.position,
		])
	player.free()
	await get_tree().physics_frame
	return landed
