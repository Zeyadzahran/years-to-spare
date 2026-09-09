@tool
extends Node2D
## Builds the hidden arena from Level 1's own terrain atlas. Keeping the cells
## procedural makes the chamber easy to resize without introducing a second
## platform style.

const TERRAIN_SOURCE := 0
const ROOM_WIDTH := 18
const FLOOR_DEPTH := 5
const WALL_HEIGHT := 5
const ARENA_CAMERA_ZOOM := Vector2(1.25, 1.25)

@onready var terrain: TileMapLayer = $Terrain
@onready var warden: Warden = $Warden


func _ready() -> void:
	_build_room_shell()
	if not Engine.is_editor_hint():
		warden.process_mode = Node.PROCESS_MODE_DISABLED


func begin_encounter() -> void:
	if is_instance_valid(warden):
		warden.velocity = Vector2.ZERO
		warden.process_mode = Node.PROCESS_MODE_INHERIT


func configure_camera(camera: Camera2D) -> void:
	camera.zoom = ARENA_CAMERA_ZOOM


func _build_room_shell() -> void:
	terrain.clear()

	# The floor uses the same top, fill, and lower-edge rows as the outdoor level.
	for x in range(ROOM_WIDTH):
		terrain.set_cell(Vector2i(x, 0), TERRAIN_SOURCE, _atlas_for_column(x, 0))
		for y in range(1, FLOOR_DEPTH - 1):
			terrain.set_cell(Vector2i(x, y), TERRAIN_SOURCE, _atlas_for_column(x, 1))
		terrain.set_cell(
			Vector2i(x, FLOOR_DEPTH - 1),
			TERRAIN_SOURCE,
			_atlas_for_column(x, 2)
		)

	# Matching terrain closes the chamber on both sides. The lower-edge atlas row
	# is used overhead so its rocky edge faces into the playable space.
	for y in range(-WALL_HEIGHT, 0):
		terrain.set_cell(Vector2i(0, y), TERRAIN_SOURCE, Vector2i(0, 1))
		terrain.set_cell(Vector2i(ROOM_WIDTH - 1, y), TERRAIN_SOURCE, Vector2i(2, 1))

	for x in range(ROOM_WIDTH):
		terrain.set_cell(Vector2i(x, -WALL_HEIGHT - 1), TERRAIN_SOURCE, _atlas_for_column(x, 2))


func _atlas_for_column(column: int, row: int) -> Vector2i:
	if column == 0:
		return Vector2i(0, row)
	if column == ROOM_WIDTH - 1:
		return Vector2i(2, row)
	return Vector2i(1, row)
