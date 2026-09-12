@tool
extends Node2D
## World-space sign: stays readable against scenery without blocking player input.
## Each row pairs a key caption with an input action and a short instruction.

const FONT = preload("res://assets/fonts/prstart.ttf")
const INK := Color("211e26")
const GOLD := Color("efbd70")
const PAPER := Color("fff0d5")
const MUTED := Color("c7b49e")

@export var heading := "GET MOVING"
@export var keys := PackedStringArray(["A / D", "W / SPACE", "S"])
@export var actions := PackedStringArray(["move_left|move_right", "jump", "crouch"])
@export var instructions := PackedStringArray(["Move", "Jump", "Crouch"])
@export var footer := ""
@export var card_width := 260.0
@export var accent := GOLD

var _elapsed := 0.0


func _process(delta: float) -> void:
	# The editor previews the same layout, but keeps the decorative arrow still.
	if not Engine.is_editor_hint():
		_elapsed += delta
	queue_redraw()


func _draw() -> void:
	var height := 48.0 + instructions.size() * 30.0
	if not footer.is_empty():
		height += 22.0
	draw_rect(Rect2(4, 5, card_width, height), Color(0.08, 0.06, 0.09, 0.3))
	draw_rect(Rect2(0, 0, card_width, height), Color(0.13, 0.12, 0.15, 0.96))
	draw_rect(Rect2(0, 0, card_width, height), accent.darkened(0.4), false, 1.0)
	draw_string(FONT, Vector2(16, 25), heading, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, accent)
	draw_line(Vector2(16, 35), Vector2(card_width - 16, 35), accent.darkened(0.65))
	for index in instructions.size():
		var y := 44.0 + index * 30.0
		var text_x := 16.0
		if index < keys.size() and not keys[index].is_empty():
			var pressed := _row_pressed(index)
			var key_color := accent if pressed else Color("423a39")
			draw_rect(Rect2(16, y + 2, 110, 23), Color("100f15"))
			draw_rect(Rect2(16, y, 110, 22), key_color)
			draw_rect(Rect2(16, y, 110, 22), accent.darkened(0.35), false)
			var caption := keys[index]
			var caption_width := FONT.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
			draw_string(FONT, Vector2(71 - caption_width / 2, y + 16), caption,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK if pressed else PAPER)
			text_x = 140.0
		draw_string(FONT, Vector2(text_x, y + 16), instructions[index],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, PAPER)
	var footer_y := height - 13.0
	draw_string(FONT, Vector2(16, footer_y), footer, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, MUTED)
	# A small travelling chevron draws the eye toward the route ahead.
	var arrow_x := card_width - 19.0 + sin(_elapsed * 2.5) * 3.0
	draw_polyline(PackedVector2Array([
		Vector2(arrow_x - 4, 13), Vector2(arrow_x + 1, 18), Vector2(arrow_x - 4, 23)
	]), accent, 2.0)


func _row_pressed(index: int) -> bool:
	if Engine.is_editor_hint() or index >= actions.size():
		return false
	for action in actions[index].split("|", false):
		if InputMap.has_action(action) and Input.is_action_pressed(action):
			return true
	return false
