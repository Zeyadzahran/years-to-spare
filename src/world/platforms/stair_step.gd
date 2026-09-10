@tool
class_name StairStep
extends StaticBody2D
## A full-depth step cut from the room's existing platform slab. Adjacent steps
## overlap so the revealed rescue route reads as one supported staircase.

@export var width := 200.0: set = _set_width

@onready var art: Sprite2D = $Art
@onready var shape: CollisionShape2D = $Shape


func _ready() -> void:
	_apply()


func _set_width(value: float) -> void:
	width = value
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	var art_size := art.texture.get_size()
	var art_scale := width / art_size.x
	var depth := art_size.y * art_scale
	art.scale = Vector2.ONE * art_scale
	art.position.y = depth * 0.5
	var box := shape.shape as RectangleShape2D
	box.size = Vector2(width, depth)
	shape.position.y = depth * 0.5
