class_name ReinforcementGate
extends Node2D
## Refined original clock/hourglass portal. Its frame stays rigid while the
## saved arena clock controls its fade, glow and travelling energy sparks.

var open_fraction := 0.0
var visual_time := 0.0
var spawn_glow := 0.0
@onready var art: Sprite2D = $Art

func set_open_fraction(fraction: float, clock := 0.0, spawn_pulse := 0.0) -> void:
	open_fraction = smoothstep(0.0, 1.0, clampf(fraction, 0.0, 1.0))
	visual_time = clock
	spawn_glow = clampf(spawn_pulse, 0.0, 1.0) * open_fraction
	visible = open_fraction > 0.0
	if art != null:
		var glow := 1.0 + sin(visual_time * 3.0) * 0.035
		art.self_modulate = Color(1.0 + spawn_glow * 0.3, glow + spawn_glow * 0.65, glow + spawn_glow * 0.85, open_fraction)
	queue_redraw()

func _draw() -> void:
	if open_fraction <= 0.0:
		return
	# Layered translucent ellipses give each spawn a soft cyan halo. The
	# arena saves the pulse clock, so it freezes and rewinds with that enemy.
	if spawn_glow > 0.0:
		draw_set_transform(Vector2(0, -82), 0.0, Vector2(1.0, 1.45))
		for i in 6:
			draw_circle(Vector2.ZERO, 68.0 - i * 7.0, Color(0.12, 0.65, 1.0, spawn_glow * 0.045))
		draw_arc(Vector2.ZERO, 30.0 + (1.0 - spawn_glow) * 30.0, 0.0, TAU, 48, Color(0.55, 0.94, 1.0, spawn_glow * 0.7), 2.0, true)
		draw_set_transform(Vector2.ZERO)
	# Only the portal's interior moves; no scaling or warping of the arch.
	for i in 9:
		var angle := visual_time * 0.85 + i * TAU / 9.0
		var radius := 12.0 + fmod(i * 7.0 - visual_time * 9.0 + 1000.0, 30.0)
		var point := Vector2(cos(angle) * radius, -78.0 + sin(angle) * radius * 1.4)
		draw_rect(Rect2(point, Vector2(1.5, 1.5)), Color(0.65, 0.95, 1.0, open_fraction * 0.65))
