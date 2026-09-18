@tool
extends Node2D
## A taunt hanging in the air over something he is meant to attempt - no box,
## no key cap, just words: they surface as he comes near and are gone for good
## once the lesson they were baiting has been given. Drawn in the world like
## the guide cards, so nothing about input or physics is touched.

const FONT := preload("res://assets/fonts/prstart.ttf")

@export var line := "I DARE YOU"
@export var sub := "JUMP IT"
## Hot, not the cards' gold: it is a taunt.
@export var accent := Color(1.0, 0.58, 0.32)
@export var ink := Color(0.13, 0.08, 0.1, 0.9)
## How close he has to be, in pixels, before the words are fully out.
@export var reveal_distance := 620.0
@export var fade_distance := 900.0
## Once this run's lesson has been given the dare has done its job.
@export var spent_when_lesson_done := true

var _elapsed := 0.0
var _shown := 1.0
var _player: Node2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_shown = 0.0
	modulate.a = 0.0


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	_elapsed += delta
	var wanted := 0.0
	if not (spent_when_lesson_done and GameState.rewind_lesson_done):
		if not is_instance_valid(_player):
			_player = get_tree().get_first_node_in_group(&"player") as Node2D
		if _player != null:
			var distance := absf(_player.global_position.x - global_position.x)
			wanted = 1.0 - clampf((distance - reveal_distance) / maxf(fade_distance - reveal_distance, 1.0), 0.0, 1.0)
	_shown = move_toward(_shown, wanted, delta * 2.0)
	modulate.a = _shown
	visible = _shown > 0.001 or Engine.is_editor_hint()
	queue_redraw()


func _draw() -> void:
	# A slow float, so it hangs rather than sits.
	var bob := sin(_elapsed * 1.6) * 4.0
	var y := bob
	_word(line, Vector2(0, y), 22)
	_word(sub, Vector2(0, y + 30), 12)
	# The way across.
	var reach := 14.0 + sin(_elapsed * 3.0) * 3.0
	var tip := Vector2(reach + 70.0, y + 24.0)
	draw_polyline(PackedVector2Array([tip + Vector2(-10, -10), tip, tip + Vector2(-10, 10)]), accent, 3.0)


## Centred text, outlined in ink so it reads on any sky.
func _word(text: String, at: Vector2, size: int) -> void:
	var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, size).x
	var origin := at + Vector2(-width * 0.5, 0)
	draw_string_outline(FONT, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, ink)
	draw_string(FONT, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, accent)
