class_name RewindOverlay
extends Control
## What a rewound world looks like. Built the same way as TimeStopOverlay -
## one full-screen rect and a label, all drawn in code - and deliberately its
## opposite in every choice it can be: Stop is warm and still, Rewind is cold
## and cannot hold a frame steady.
##
##   1. the picture drains to a cold silver and the rows start to slip, the
##      way tape does when it is run the wrong way through the heads;
##   2. a ring runs *in* from the edges to the boy, dragging the image with it
##      - the shove that started the world back, aimed the other way;
##   3. a dial counts the window back, hand sweeping anticlockwise.
##
## Ticks on the raw frame delta, like its sibling: this has to keep moving
## while TimeService is holding everything else still.

## Cold, pale and slightly blue: the palette every other game reaches for on
## a *freeze*, used here on the one power that is not one.
const SILVER := Color(0.72, 0.82, 0.95)

const FONT := preload("res://assets/fonts/prstart.ttf")

const FADE_IN := 0.12
const FADE_OUT := 0.3
## How long the inward wave takes to reach the boy.
const BURST_TIME := 0.45
const TITLE_HOLD := 0.8
const TITLE_FADE := 0.4

const SHADER := """
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float burst : hint_range(0.0, 1.0) = 0.0;
uniform float clock = 0.0;
uniform vec2 focus = vec2(0.5, 0.5);
uniform vec2 aspect = vec2(1.777, 1.0);
uniform vec4 silver : source_color = vec4(0.72, 0.82, 0.95, 1.0);

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 offset = (uv - focus) * aspect;
	float radius = length(offset);
	vec2 dir = offset / max(radius, 0.0001);

	// The wave front, coming in from the edges. `burst` runs 1 -> 0, so the
	// ring starts off the screen and lands on the boy as it is spent.
	float front = burst;
	float ring = 1.0 - smoothstep(0.0, 0.07, abs(radius - front * 1.3));
	ring *= burst;

	// Tracking: whole rows slip sideways by an amount that changes a few
	// times a second, and a band of them slips further as it rolls up the
	// frame. Nothing about the picture is allowed to sit still.
	float row = floor(uv.y * 160.0);
	float slip = (hash(row + floor(clock * 14.0)) - 0.5) * 0.012;
	float band = 1.0 - smoothstep(0.0, 0.06, abs(fract(uv.y + clock * 0.35) - 0.5));
	slip += (hash(row * 3.1 + floor(clock * 30.0)) - 0.5) * 0.03 * band;
	uv.x += slip * strength;

	// The image gets pulled in with the ring, and its channels pull apart.
	vec2 push = dir * ring * 0.03;
	float split = ring * 0.006 + strength * 0.0025;
	vec2 warped = uv + push;
	vec3 col;
	col.r = texture(screen, warped + vec2(split, 0.0)).r;
	col.g = texture(screen, warped).g;
	col.b = texture(screen, warped - vec2(split, 0.0)).b;

	// Drained to luminance, then poured back through silver.
	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 caught = mix(vec3(grey), silver.rgb * (grey * 1.2 + 0.06), 0.7);
	col = mix(col, caught, strength);

	// Scanlines, and a faint flicker over the whole frame.
	float scan = 0.5 + 0.5 * sin(uv.y * 900.0);
	col *= mix(1.0, 0.86 + 0.14 * scan, strength);
	col *= mix(1.0, 0.94 + 0.06 * hash(floor(clock * 24.0)), strength);

	// Edges close in, so the eye is pushed to the boy.
	float vignette = smoothstep(1.05, 0.3, length((uv - 0.5) * aspect));
	col *= mix(1.0, mix(0.45, 1.0, vignette), strength);

	col += silver.rgb * ring * 0.85;
	COLOR = vec4(col, 1.0);
}
"""

var _screen: ColorRect
var _dial: Control
var _title: Label

var _strength := 0.0
var _target := 0.0
var _burst := 0.0
var _clock := 0.0

var _focus := Vector2(0.5, 0.5)
var _remaining := 0.0
var _duration := 1.0

var _title_left := 0.0
var _title_span := 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader := Shader.new()
	shader.code = SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"silver", SILVER)

	_screen = ColorRect.new()
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.material = material
	_screen.hide()
	add_child(_screen)

	_dial = Control.new()
	_dial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dial.draw.connect(_draw_dial)
	add_child(_dial)

	_title = Label.new()
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = 84.0
	_title.offset_bottom = 132.0
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_override(&"font", FONT)
	_title.add_theme_font_size_override(&"font_size", 26)
	_title.add_theme_color_override(&"font_outline_color", Color(0.043, 0.039, 0.035, 0.9))
	_title.add_theme_constant_override(&"outline_size", 10)
	_title.modulate.a = 0.0
	add_child(_title)
	set_process(false)


## The rewind has taken hold: the world is now running backward.
func begin(duration: float) -> void:
	set_process(true)
	_duration = maxf(duration, 0.001)
	_remaining = _duration
	_target = 1.0
	_burst = 1.0
	_say("<< REWINDING", SILVER, TITLE_HOLD)


## Time is running forward again. A smaller wave out from the boy this time -
## the direction Stop's goes - so the picture visibly lets go of him.
func end() -> void:
	set_process(true)
	_target = 0.0
	_burst = maxf(_burst, 0.4)
	_remaining = 0.0


func set_focus(uv: Vector2) -> void:
	_focus = uv


func set_remaining(seconds: float) -> void:
	_remaining = seconds


func _say(text: String, colour: Color, hold: float) -> void:
	set_process(true)
	_title.text = text
	_title.add_theme_color_override(&"font_color", colour)
	_title_span = hold + TITLE_FADE
	_title_left = _title_span


func _process(delta: float) -> void:
	_clock += delta
	var rate := 1.0 / (FADE_IN if _target > _strength else FADE_OUT)
	_strength = move_toward(_strength, _target, rate * delta)
	_burst = maxf(_burst - delta / BURST_TIME, 0.0)

	var live := _strength > 0.001 or _burst > 0.001
	_screen.visible = live
	if live:
		var material := _screen.material as ShaderMaterial
		material.set_shader_parameter(&"strength", _strength)
		material.set_shader_parameter(&"burst", _burst)
		material.set_shader_parameter(&"clock", _clock)
		material.set_shader_parameter(&"focus", _focus)
		material.set_shader_parameter(&"aspect", Vector2(size.x / maxf(size.y, 1.0), 1.0))

	if _title_left > 0.0:
		_title_left = maxf(_title_left - delta, 0.0)
		var age := 1.0 - _title_left / _title_span
		var punch := 1.0 + 0.35 * maxf(1.0 - age * 5.0, 0.0)
		_title.pivot_offset = _title.size * 0.5
		_title.scale = Vector2(punch, punch)
		_title.modulate.a = minf(_title_left / TITLE_FADE, 1.0)
		# The title itself cannot hold still either.
		_title.position.x = (randf() - 0.5) * 6.0 * _strength

	_dial.queue_redraw()
	if not live and _title_left <= 0.0:
		set_process(false)


## The window, as a clock hand sweeping *back* from noon over the boy's head.
func _draw_dial() -> void:
	if _remaining <= 0.0 or _strength <= 0.01:
		return
	var centre := Vector2(size.x * 0.5, 168.0)
	var radius := 30.0
	var left := clampf(_remaining / _duration, 0.0, 1.0)
	var fade := Color(SILVER, _strength)

	_dial.draw_arc(centre, radius, 0.0, TAU, 48, Color(0.043, 0.039, 0.035, 0.55 * _strength), 7.0, true)
	# Anticlockwise: the arc runs from noon backwards, and shrinks towards it.
	_dial.draw_arc(centre, radius, -PI * 0.5 - TAU * left, -PI * 0.5, 48, fade, 4.0, true)
	var head := centre + Vector2.from_angle(-PI * 0.5 - TAU * left) * radius
	_dial.draw_circle(head, 4.5, Color(0.92, 0.96, 1.0, _strength))
	for i in 4:
		var at := centre + Vector2.from_angle(-PI * 0.5 + TAU * i / 4.0) * (radius + 9.0)
		_dial.draw_circle(at, 2.0, Color(SILVER, 0.5 * _strength))
