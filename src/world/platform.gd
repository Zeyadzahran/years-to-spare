@tool
class_name Platform
extends StaticBody2D
## Solid ground, sized from the inspector. A placeholder block now, a tileset
## chunk once the art lands.

@export var size := Vector2(160.0, 24.0): set = _set_size
@export var color := Color(0.16, 0.16, 0.24): set = _set_color

@onready var rect: ColorRect = $Rect
@onready var shape: CollisionShape2D = $Shape

func _ready() -> void:
	_apply()


func _set_size(value: Vector2) -> void:
	size = value
	_apply()


func _set_color(value: Color) -> void:
	color = value
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	rect.size = size
	rect.position = -size * 0.5
	rect.color = color
	var box := shape.shape as RectangleShape2D
	if box:
		box.size = size
