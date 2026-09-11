class_name BossImpactEffect
extends Node2D
## Something heavy has hit the floor here. Shared by the guardian's feet and the
## stones, and scaled by `strength` so a pebble and a slam are the same event
## at different sizes.
##
## Four layers, from fastest to slowest, because an impact is read over time
## and not in one frame:
##
##   1. a flash and a ring running out along the ground - the first two frames,
##      the "hit" itself;
##   2. stone chips off the rock sheet thrown up and falling back, with embers
##      for the heavy ones;
##   3. dust: a sideways burst that hangs, and a slow plume behind it on the
##      heavy hits;
##   4. cracks and a dark scuff left in the floor, fading out over a couple of
##      seconds so the arena keeps a memory of where things landed.
##
## Cleans itself up once the last of that is gone. Everything follows the
## world's clock: a stopped world holds the chips in the air.

const RING_LIFE := 0.5
const CRACK_LIFE := 2.6

var strength := 1.0
var floor_wave := false

var _age := 0.0
var _cracks: Array[PackedVector2Array] = []
var _particles: Array[CPUParticles2D] = []


func configure(at: Vector2, effect_strength := 1.0, wide_floor_wave := false) -> void:
	global_position = at
	strength = effect_strength
	floor_wave = wide_floor_wave
	_build_cracks()
	_spawn_particles()
	_shake_camera()
	queue_redraw()


func _process(delta: float) -> void:
	var scaled := TimeService.world_delta(delta)
	# One-shots free themselves when spent; drop them as they go.
	var live: Array[CPUParticles2D] = []
	for particles in _particles:
		if is_instance_valid(particles):
			live.append(particles)
			particles.speed_scale = TimeService.world_scale
	_particles = live
	if is_zero_approx(scaled):
		return
	_age += scaled
	queue_redraw()
	if _age >= CRACK_LIFE and _particles.is_empty():
		queue_free()


func _spawn_particles() -> void:
	var at := global_position
	var heavy := strength >= 0.9 or floor_wave
	var dust := BossVfx.dust_burst(self, at, strength, floor_wave)
	_particles.append(dust)
	_particles.append(BossVfx.debris_burst(self, at, int(4.0 + 6.0 * strength), strength, false))
	if floor_wave:
		_particles.append(BossVfx.debris_burst(self, at, 6, strength * 0.9, true))
	if heavy:
		var plume := BossVfx.dust_plume(self, at, strength, -1)
		_particles.append(plume)
		_particles.append(BossVfx.spark_burst(self, at, 7 if floor_wave else 4, strength))
		if floor_wave:
			# The guardian's own dust goes up behind it. In front, it hid the
			# body for the first second of the open window - the one second
			# the player is meant to be looking at it.
			for cloud in [dust, plume]:
				cloud.z_as_relative = false
				cloud.z_index = 5


func _shake_camera() -> void:
	var rig := BossCameraRig.find(get_tree())
	if rig != null:
		rig.add_trauma_at(0.16 * strength, global_position)


func _build_cracks() -> void:
	# Each crack is a jagged line out from the hit, with a fork partway along.
	# Random within limits, so no two stones scar the floor the same way.
	_cracks.clear()
	var count := 5 if floor_wave else 3
	var reach := (88.0 if floor_wave else 52.0) * strength
	for index in count:
		var side := -1.0 if index % 2 == 0 else 1.0
		var length := reach * randf_range(0.55, 1.0)
		var lift := randf_range(-6.0, 2.0)
		var line := PackedVector2Array([Vector2(side * 4.0, 0.0)])
		var segments := 3 + randi() % 2
		for segment in segments:
			var along := float(segment + 1) / float(segments)
			line.append(Vector2(side * length * along,
				lift * along + randf_range(-5.0, 5.0) * (1.0 - along * 0.5)))
		_cracks.append(line)
		if randf() < 0.7:
			var root := line[1 + randi() % (line.size() - 2)]
			_cracks.append(PackedVector2Array([
				root,
				root + Vector2(side * randf_range(8.0, 18.0), randf_range(-14.0, -6.0)),
				root + Vector2(side * randf_range(20.0, 34.0), randf_range(-10.0, -2.0)),
			]))


func _draw() -> void:
	var ring_progress := clampf(_age / RING_LIFE, 0.0, 1.0)
	var settle := 1.0 - clampf(_age / CRACK_LIFE, 0.0, 1.0)
	settle *= settle

	# The scuff and cracks first, under everything else.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, (30.0 if floor_wave else 18.0) * strength,
		Color(0.09, 0.05, 0.03, 0.42 * settle))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for crack in _cracks:
		# A pale edge a pixel above the dark line, which is what makes a crack
		# read as a split in the floor rather than a line drawn on it.
		var lit := PackedVector2Array()
		for point in crack:
			lit.append(point + Vector2(0.0, -1.5))
		draw_polyline(lit, Color(0.95, 0.72, 0.46, 0.5 * settle), 1.5, true)
		draw_polyline(crack, Color(0.12, 0.06, 0.04, 0.9 * settle), 2.5, true)

	if ring_progress < 1.0:
		var fade := 1.0 - ring_progress
		var reach := lerpf(10.0, 94.0 * strength, ease(ring_progress, 0.4))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
		if ring_progress < 0.22:
			var flash_fade := 1.0 - ring_progress / 0.22
			draw_circle(Vector2.ZERO, lerpf(6.0, 40.0 * strength, ring_progress / 0.22),
				Color(1.0, 0.85, 0.55, 0.6 * flash_fade))
		# Two rings a beat apart, the outer one brighter: the front and the
		# ground settling behind it.
		draw_arc(Vector2.ZERO, reach, 0.0, TAU, 40,
			Color(1.0, 0.68, 0.3, 0.85 * fade), maxf(1.5, 7.0 * fade), true)
		draw_arc(Vector2.ZERO, reach * 0.72, 0.0, TAU, 40,
			Color(0.95, 0.5, 0.18, 0.45 * fade), maxf(1.0, 4.0 * fade), true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
