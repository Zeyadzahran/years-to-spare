@tool
extends StaticBody2D
## Art stays proportional; collision size can be tuned independently for gameplay.
@export var collision_size := Vector2(110, 70):
	set(value):
		collision_size = Vector2(maxf(value.x, 1), maxf(value.y, 1))
		_apply()
@export var collision_offset := Vector2.ZERO:
	set(value):
		collision_offset = value
		_apply()
@export_range(1.0, 512.0) var art_width := 110.0:
	set(value):
		art_width = maxf(value, 1)
		_apply()

func _ready() -> void:
	_apply()

func _apply() -> void:
	if not is_node_ready():
		return
	($Shape.shape as RectangleShape2D).size = collision_size
	$Shape.position = Vector2(0, -collision_size.y * 0.5) + collision_offset
	$Cargo.scale = Vector2.ONE * art_width / $Cargo.texture.get_width()
