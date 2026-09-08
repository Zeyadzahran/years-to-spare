class_name TimeStopOverlay
extends Control
## What a stopped world looks like. Everything here is drawn - no new art - so
## it can land before anyone has to paint anything.
##
## Three things fire at once, because "the time is stopped" has to be legible in
## the half second before the player looks at the HUD:
##
##   1. the picture drains to amber and darkens at the edges, so the world reads
##      as caught in resin rather than merely paused;
##   2. a ring leaves the boy and runs off the screen, dragging the image and
##      splitting its colour channels as it goes - the shove that stopped it;
##   3. a clock dial counts the window down over his head.
##
## The whole thing is built in code rather than authored as a scene: it is one
## full-screen rect and two labels, and keeping it here means the HUD scene does
## not have to be reopened to tune it.
##
## Ticks on the raw frame delta on purpose. This is the one thing on screen that
## must keep moving while TimeService is holding everything else still.

## Amber, matching the clock plate and the boy's own aura, rather than the blue
## every other game reaches for. He is not freezing the world, he is ageing.
const RESIN := Color(1.0, 0.78, 0.38)
const REFUSED := Color(0.95, 0.42, 0.36)

const FONT := preload("res://assets/fonts/prstart.ttf")

## Seconds for the tint to close in and to let go again.
const FADE_IN := 0.16
const FADE_OUT := 0.3
## How long the shockwave takes to cross the screen.
const BURST_TIME := 0.5
## How long the headline holds before it gets out of the way of the game.
const TITLE_HOLD := 0.9
const TITLE_FADE := 0.45

const SHADER := """
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float burst : hint_range(0.0, 1.0) = 0.0;
uniform float clock = 0.0;
uniform vec2 focus = vec2(0.5, 0.5);
uniform vec2 aspect = vec2(1.777, 1.0);
uniform vec4 resin : source_color = vec4(1.0, 0.78, 0.38, 1.0);

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 offset = (uv - focus) * aspect;
	float radius = length(offset);
	vec2 dir = offset / max(radius, 0.0001);

	// The wave front, travelling out from the boy. `burst` runs 1 -> 0, so the
	// ring starts on top of him and is off the screen by the time it is spent.
	float front = 1.0 - burst;
	float ring = 1.0 - smoothstep(0.0, 0.07, abs(radius - front * 1.3));
	ring *= burst;

	// The image gets shoved along with it, and its channels pull apart. That
	// tear is what sells the stop as something done *to* the world.
	vec2 push = dir * ring * 0.03;
	float split = ring * 0.006 + strength * 0.0015;
	vec2 warped = uv - push;
	vec3 col;
	col.r = texture(screen, warped + dir * split).r;
	col.g = texture(screen, warped).g;
	col.b = texture(screen, warped - dir * split).b;

	// Drained to luminance, then poured back through amber: colour is the first
	// thing a running world has and the first thing a stopped one loses.
	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 caught = mix(vec3(grey), resin.rgb * (grey * 1.25 + 0.05), 0.62);
	col = mix(col, caught, strength);

	// Edges close in, so the eye is pushed to the middle of the screen where
	// the boy and the dial are.
	float vignette = smoothstep(1.05, 0.3, length((uv - 0.5) * aspect));
	col *= mix(1.0, mix(0.42, 1.0, vignette), strength);

	// Slow bands crawling up the frame: the only motion left in the picture.
	col += resin.rgb * (sin(uv.y * 190.0 - clock * 1.6) * 0.5 + 0.5) * 0.022 * strength;

	col += resin.rgb * ring * 0.85;
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
	# The level is paused underneath the options panel; the freeze should hold
	# its last frame with it rather than keep breathing behind the menu.
	process_mode = Node.PROCESS_MODE_PAUSABLE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader := Shader.new()
	shader.code = SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter(&"resin", RESIN)

	_screen = ColorRect.new()
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.material = material
	# Hidden while nothing is happening: the shader copies the whole framebuffer
	# every frame it draws, and idle is most of them.
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


## One press has landed. Runs the shockwave, pulls the colour out of the world
## and starts the dial.
func begin(duration: float) -> void:
	set_process(true)
	_duration = maxf(duration, 0.001)
	_remaining = _duration
	_target = 1.0
	_burst = 1.0
	_say("TIME STOPPED", RESIN, TITLE_HOLD)


## The window has run out. A smaller wave going the other way, so the world
## visibly starts again instead of the tint simply being switched off.
func end() -> void:
	set_process(true)
	_target = 0.0
	_burst = maxf(_burst, 0.5)
	_remaining = 0.0


func set_focus(uv: Vector2) -> void:
	_focus = uv


func set_remaining(seconds: float) -> void:
	_remaining = seconds


## Says why a press did nothing. Without this a refused cast is indistinguishable
## from a dropped input.
func refuse(missing_years: float) -> void:
	_say("NEED %d MORE YEARS" % maxi(roundi(missing_years), 1), REFUSED, 0.8)


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
		# Punches in over the first fifth of its life, then holds, then goes.
		var age := 1.0 - _title_left / _title_span
		var punch := 1.0 + 0.35 * maxf(1.0 - age * 5.0, 0.0)
		_title.pivot_offset = _title.size * 0.5
		_title.scale = Vector2(punch, punch)
		_title.modulate.a = minf(_title_left / TITLE_FADE, 1.0)

	_dial.queue_redraw()
	if not live and _title_left <= 0.0:
		set_process(false)


## The window, as a clock hand sweeping back to noon over the boy's head.
func _draw_dial() -> void:
	if _remaining <= 0.0 or _strength <= 0.01:
		return
	var centre := Vector2(size.x * 0.5, 168.0)
	var radius := 30.0
	var left := clampf(_remaining / _duration, 0.0, 1.0)
	var fade := Color(RESIN, _strength)

	_dial.draw_arc(centre, radius, 0.0, TAU, 48, Color(0.043, 0.039, 0.035, 0.55 * _strength), 7.0, true)
	_dial.draw_arc(centre, radius, -PI * 0.5, -PI * 0.5 + TAU * left, 48, fade, 4.0, true)
	# The head of the hand, so the sweep has something to follow.
	var head := centre + Vector2.from_angle(-PI * 0.5 + TAU * left) * radius
	_dial.draw_circle(head, 4.5, Color(1.0, 0.96, 0.85, _strength))
	# Quarter marks, so a glance reads "about half left" without counting.
	for i in 4:
		var at := centre + Vector2.from_angle(-PI * 0.5 + TAU * i / 4.0) * (radius + 9.0)
		_dial.draw_circle(at, 2.0, Color(RESIN, 0.5 * _strength))
