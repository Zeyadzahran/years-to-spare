@tool
extends StaticBody2D
## Width changes keep the two end caps and collision aligned with the walking surface.
@export_range(2, 32, 1) var width_tiles := 3:
	set(value):
		width_tiles = maxi(value, 2)
		_apply()
@export var one_way := true:
	set(value):
		one_way = value
		_apply()

func _ready() -> void:
	_apply()

func _apply() -> void:
	if not is_node_ready():
		return
	var width := width_tiles * 64.0
	$Left.position.x = -width * 0.5 + 32.0
	$Right.position.x = width * 0.5 - 32.0
	$Middle.visible = width_tiles > 2
	$Middle.region_rect = Rect2(0, 0, (width_tiles - 2) * 32, 32)
	($Shape.shape as RectangleShape2D).size = Vector2(width, 24)
	$Shape.one_way_collision = one_way
