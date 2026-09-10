class_name BossImpactEffect
extends Node2D
## Short, deterministic dust-and-fragment burst shared by the titan's feet and
## the stones. It is drawn in the room's warm rock palette and cleans itself up.

const LIFE := 0.46

var strength := 1.0
var floor_wave := false
var _age := 0.0


func configure(at: Vector2, effect_strength := 1.0, wide_floor_wave := false) -> void:
	global_position = at
	strength = effect_strength
	floor_wave = wide_floor_wave
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if _age >= LIFE:
		queue_free()


func _draw() -> void:
	var progress := clampf(_age / LIFE, 0.0, 1.0)
	var fade := 1.0 - progress
	var reach := lerpf(16.0, 76.0 * strength, progress)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.28))
	draw_arc(Vector2.ZERO, reach, PI, TAU, 28,
		Color(1.0, 0.55, 0.16, 0.72 * fade), maxf(1.0, 6.0 * fade), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	var puff_count := 9 if floor_wave else 6
	for index in puff_count:
		var ratio := float(index) / maxf(float(puff_count - 1), 1.0)
		var angle := lerpf(PI * 1.08, PI * 1.92, ratio)
		var distance := reach * lerpf(0.35, 0.9, fmod(float(index) * 0.63, 1.0))
		var puff_position := Vector2.from_angle(angle) * distance
		puff_position.y *= 0.52
		var radius := lerpf(9.0, 3.0, progress) * strength
		draw_circle(puff_position, radius,
			Color(0.72, 0.43, 0.23, 0.58 * fade))

	var fragment_count := 7 if floor_wave else 4
	for index in fragment_count:
		var direction := -1.0 if index % 2 == 0 else 1.0
		var horizontal := direction * (12.0 + float(index) * 7.0) * strength
		var fragment_position := Vector2(horizontal * progress,
			-sin(progress * PI) * (24.0 + float(index % 3) * 9.0) * strength)
		var fragment_size := maxf(2.0, (5.0 - progress * 2.0) * strength)
		draw_colored_polygon(PackedVector2Array([
			fragment_position + Vector2(-fragment_size, 0.0),
			fragment_position + Vector2(0.0, -fragment_size),
			fragment_position + Vector2(fragment_size, 1.0),
			fragment_position + Vector2(0.0, fragment_size),
		]), Color(0.38, 0.34, 0.36, 0.9 * fade))

	if floor_wave:
		for side in [-1.0, 1.0]:
			var crack_end := Vector2(side * reach * 1.45, 0.0)
			draw_polyline(PackedVector2Array([
				Vector2(side * 10.0, 0.0),
				Vector2(side * reach * 0.55, -4.0),
				Vector2(side * reach, 2.0),
				crack_end,
			]), Color(0.19, 0.12, 0.09, 0.72 * fade), 3.0)
