class_name BossScreenFx
extends Node2D
## Full-screen response to the guardian: the picture itself is hit, not just the
## floor under it. Built the same way as TimeStopOverlay - one quad, one
## shader, nothing to author.
##
## It lives in the world canvas rather than on a CanvasLayer, drawn last by z
## and re-fitted to the camera's view every frame. That is what keeps it under
## the HUD: a layer would have to fight the hud scene for ordering, and the
## bars must stay sharp while the room behind them is torn.
##
## Three effects, all driven from `_process` on the raw delta:
##
##   - shockwave: a ring of displacement running out from a world point, with
##     the colour channels pulled apart along its front. Two slots, because a
##     stone can land while a stomp's wave is still crossing the screen;
##   - flash: a short wash of colour over the frame, for the slam itself and
##     for the guardian's death;
##   - vignette: the edges close in and let go again, the "brace" before a
##     heavy hit lands and the pulse of a phase change.
##
## Hidden while idle: the shader copies the framebuffer every frame it draws.

const SHADER := """
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform vec2 aspect = vec2(1.777, 1.0);
// x, y: centre in screen UV. z: radius in aspect-corrected UV. w: strength.
uniform vec4 wave_a = vec4(0.5, 0.5, 0.0, 0.0);
uniform vec4 wave_b = vec4(0.5, 0.5, 0.0, 0.0);
uniform float wave_width = 0.11;
uniform vec4 flash : source_color = vec4(1.0, 0.9, 0.7, 0.0);
uniform float vignette : hint_range(0.0, 1.0) = 0.0;
uniform vec4 vignette_color : source_color = vec4(0.12, 0.04, 0.02, 1.0);

float ring(vec4 wave, vec2 uv, inout vec2 push, inout float split) {
	vec2 offset = (uv - wave.xy) * aspect;
	float radius = length(offset);
	vec2 dir = offset / max(radius, 0.0001);
	// Sharper on the inside than the outside: the ground ahead of the front is
	// compressed, the ground behind it is left settling.
	float band = abs(radius - wave.z);
	float front = 1.0 - smoothstep(0.0, wave_width, band);
	front *= wave.w;
	push += dir * front * 0.034;
	split += front * 0.005;
	return front;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 push = vec2(0.0);
	float split = 0.0;
	float glow = ring(wave_a, uv, push, split) + ring(wave_b, uv, push, split);
	vec2 warped = uv - push;
	vec2 tear = normalize(uv - vec2(0.5)) * split;
	vec3 col;
	col.r = texture(screen, warped + tear).r;
	col.g = texture(screen, warped).g;
	col.b = texture(screen, warped - tear).b;
	// The front carries a little of the torchlight with it.
	col += vec3(1.0, 0.72, 0.4) * glow * 0.18;
	col = mix(col, flash.rgb, flash.a);
	float edge = smoothstep(0.42, 1.08, length((uv - 0.5) * aspect));
	col = mix(col, vignette_color.rgb, edge * vignette);
	COLOR = vec4(col, 1.0);
}
"""

const WAVE_TIME := 0.62
const WAVE_REACH := 1.35

var _material: ShaderMaterial
var _live := false
var _waves: Array[Dictionary] = []
var _flash := Color(1.0, 0.9, 0.7, 0.0)
var _flash_fade := 6.0
var _vignette := 0.0
var _vignette_target := 0.0
var _vignette_speed := 4.0


static func find(tree: SceneTree) -> BossScreenFx:
	return tree.get_first_node_in_group(&"boss_screen_fx") as BossScreenFx


func _ready() -> void:
	add_to_group(&"boss_screen_fx")
	top_level = true
	z_as_relative = false
	# Over everything the room draws (the impact bursts sit at 16) and under
	# nothing else in the world canvas; the HUD's own layer draws after this.
	z_index = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	# After the camera rig has moved the camera for this frame, not before:
	# the quad is fitted to the view the frame will actually draw.
	process_priority = 100
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	material = _material
	hide()
	set_process(false)


## A ring out from a world point. `strength` of one is a full stomp.
func shockwave(world_point: Vector2, strength := 1.0) -> void:
	if _waves.size() >= 2:
		# Two slots: drop the older wave, which is the fainter one by now.
		_waves.pop_front()
	_waves.append({"at": world_point, "age": 0.0, "strength": clampf(strength, 0.0, 1.0)})
	_wake()


func flash(color: Color, strength: float, fade := 6.0) -> void:
	if strength <= _flash.a:
		return
	_flash = color
	_flash.a = clampf(strength, 0.0, 1.0)
	_flash_fade = fade
	_wake()


## Close the edges in to `amount` and hold; call again with zero to let go.
func set_vignette(amount: float, speed := 4.0) -> void:
	_vignette_target = clampf(amount, 0.0, 1.0)
	_vignette_speed = speed
	_wake()


## A single squeeze and release.
func pulse_vignette(amount: float) -> void:
	_vignette = maxf(_vignette, clampf(amount, 0.0, 1.0))
	_vignette_speed = 2.6
	_wake()


func _wake() -> void:
	set_process(true)
	_live = true
	show()


func _draw() -> void:
	if not _live:
		return
	# The quad is the screen: the inverse canvas transform puts this node's
	# origin at the top-left of the view, with the camera's zoom and roll. It
	# is drawn a good deal larger than the view - the shader works in
	# SCREEN_UV, so the overhang costs nothing and a shake or roll between
	# the fit and the draw cannot leave a strip of the frame untouched.
	var size := get_viewport().get_visible_rect().size
	draw_rect(Rect2(-size * 0.5, size * 2.0), Color.WHITE)


func _process(delta: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	global_transform = get_viewport().get_canvas_transform().affine_inverse()
	queue_redraw()
	_material.set_shader_parameter(&"aspect", Vector2(viewport_size.x / maxf(viewport_size.y, 1.0), 1.0))

	var slots := [Vector4(0.5, 0.5, 0.0, 0.0), Vector4(0.5, 0.5, 0.0, 0.0)]
	var live_waves: Array[Dictionary] = []
	for wave in _waves:
		wave["age"] += delta
		var progress: float = wave["age"] / WAVE_TIME
		if progress >= 1.0:
			continue
		live_waves.append(wave)
		# Re-projected every frame: the camera is shaking while the ring runs,
		# and the ring belongs to the floor, not to the screen.
		var uv := _to_screen_uv(wave["at"])
		# Fast out of the gate, slowing as it spreads, and fading as it goes.
		var radius := ease(progress, 0.42) * WAVE_REACH
		var strength: float = wave["strength"] * (1.0 - progress) * (1.0 - progress)
		slots[live_waves.size() - 1] = Vector4(uv.x, uv.y, radius, strength)
	_waves = live_waves
	_material.set_shader_parameter(&"wave_a", slots[0])
	_material.set_shader_parameter(&"wave_b", slots[1])

	_flash.a = maxf(_flash.a - _flash_fade * delta * maxf(_flash.a, 0.12), 0.0)
	_material.set_shader_parameter(&"flash", _flash)

	_vignette = move_toward(_vignette, _vignette_target, _vignette_speed * delta)
	_material.set_shader_parameter(&"vignette", _vignette)

	if _waves.is_empty() and _flash.a <= 0.0 and is_zero_approx(_vignette) \
			and is_zero_approx(_vignette_target):
		_live = false
		hide()
		set_process(false)


func _to_screen_uv(world_point: Vector2) -> Vector2:
	var viewport := get_viewport()
	var screen_point := viewport.get_canvas_transform() * world_point
	var size := viewport.get_visible_rect().size
	return Vector2(screen_point.x / maxf(size.x, 1.0), screen_point.y / maxf(size.y, 1.0))
