class_name StatBar
extends Control
## One of the two HUD meters. The frame is a piece of art with a hole punched
## through it - the heart plate for health, the clock plate for the power line -
## so the fill is drawn first and the sprite laid over the top of it. That order
## is what lets the artwork keep its own bevels and rivets over the fill instead
## of the fill covering them.
##
## Everything is drawn by hand rather than assembled from TextureProgressBar so
## the trough can carry the two things the meters actually need: a ghost fill
## that drains behind a hit, and a pulse while a time power is held.

## Where the hole sits inside `frame`, as a fraction of the texture. Measured
## off the art rather than guessed, and near enough identical for both plates,
## so one default covers them; re-measure if the frames are ever redrawn.
@export var trough := Rect2(0.1514, 0.5098, 0.7517, 0.1709)
@export var frame: Texture2D

@export_group("Colours")
@export var fill_color := Color(0.78, 0.24, 0.28)
## The lagging fill left behind by a hit. Bright, so the size of the loss is
## legible for the moment it takes to drain away.
@export var ghost_color := Color(0.96, 0.66, 0.36)
@export var back_color := Color(0.055, 0.05, 0.047, 0.9)

## Ratios per second. The ghost holds still for `GHOST_DELAY` first, so the hit
## registers before the bar starts catching up.
const GHOST_SPEED := 0.9
const GHOST_DELAY := 0.22

## Set by the HUD while a time power is held: the fill breathes towards
## `ghost_color` so the line reads as live, not just full.
var channelling := false:
	set(value):
		channelling = value
		if not value:
			_pulse = 0.0
		queue_redraw()

var _ratio := 1.0
var _ghost := 1.0
## The first reading is the starting state, not a change: the power line opens
## near empty at 14, and without this it would play a full-bar drain on spawn.
var _seeded := false
var _hold := 0.0
var _pulse := 0.0

func _ready() -> void:
	if frame != null:
		# The plates are drawn far larger than the HUD needs them; the ratio is
		# what matters, so height follows whatever width the container gives.
		custom_minimum_size.y = custom_minimum_size.x * frame.get_height() / frame.get_width()


func _process(delta: float) -> void:
	var dirty := false
	if channelling:
		_pulse = fmod(_pulse + delta * 3.0, TAU)
		dirty = true
	if _ghost > _ratio:
		_hold = maxf(_hold - delta, 0.0)
		if is_zero_approx(_hold):
			_ghost = maxf(_ghost - GHOST_SPEED * delta, _ratio)
			dirty = true
	if dirty:
		queue_redraw()


func set_value(current: float, maximum: float) -> void:
	var next := clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
	if not _seeded:
		_seeded = true
		_ratio = next
		_ghost = next
		queue_redraw()
		return
	if next < _ratio:
		# Only a loss leaves a ghost; healing just fills.
		_hold = GHOST_DELAY
	else:
		_ghost = next
	_ratio = next
	_ghost = maxf(_ghost, next)
	queue_redraw()


func _draw() -> void:
	var inner := Rect2(trough.position * size, trough.size * size)
	draw_rect(inner, back_color)

	if _ghost > _ratio:
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * _ghost, inner.size.y)), ghost_color)

	var fill := fill_color
	if channelling:
		# Trough of the sine is 0, so a held power never dims below its resting
		# colour - it only ever brightens.
		fill = fill_color.lerp(ghost_color, (sin(_pulse) + 1.0) * 0.3)
	if _ratio > 0.0:
		draw_rect(Rect2(inner.position, Vector2(inner.size.x * _ratio, inner.size.y)), fill)

	if frame != null:
		draw_texture_rect(frame, Rect2(Vector2.ZERO, size), false)
