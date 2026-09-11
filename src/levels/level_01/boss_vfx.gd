class_name BossVfx
extends Object
## Particle builders shared by everything in the boss fight that throws dirt
## around: the titan's feet, the falling stones, the shockwaves and the crumbling
## death. Built in code rather than authored as scenes for the same reason as
## SwordEffects - one place to tune, no scene to reopen - and every emitter is
## fed from the room's own rock sheet so the debris matches the floor it came
## off, instead of being coloured squares.
##
## Everything returned here obeys the boy's time powers through `tick()`: the
## owner calls it each frame with the world scale, and a stopped world holds
## its dust in the air exactly where it was.

const ROCK_SHEET := preload("res://src/levels/level_01/art/props/rocks_and_dirt.png")

## The two smallest grey stones and the two smallest dirt clods on the sheet,
## tight-cropped. Anything bigger reads as a rock in its own right rather than
## as a chip knocked off one.
const GREY_CHIPS := [Rect2(58, 104, 27, 23), Rect2(131, 84, 41, 42)]
const DIRT_CHIPS := [Rect2(58, 354, 35, 30), Rect2(131, 345, 45, 39)]

## The floor's own tones, sampled off the tiles: lit sand on top, the darker
## packed earth underneath, and the near-black the room's shadows are drawn in.
const DUST_LIT := Color(0.93, 0.66, 0.38)
const DUST_MID := Color(0.66, 0.4, 0.22)
const DUST_DARK := Color(0.28, 0.16, 0.1)
const EMBER := Color(1.0, 0.56, 0.16)

static var _soft: Texture2D
static var _chips: Dictionary = {}


## A soft round puff, white so the emitter's colour ramp tints it.
static func soft_texture() -> Texture2D:
	if _soft == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.42, 1.0])
		gradient.colors = PackedColorArray([
			Color(1, 1, 1, 1), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 48
		texture.height = 48
		_soft = texture
	return _soft


static func chip_texture(region: Rect2) -> Texture2D:
	if not _chips.has(region):
		var atlas := AtlasTexture.new()
		atlas.atlas = ROCK_SHEET
		atlas.region = region
		_chips[region] = atlas
	return _chips[region]


## Positions are global throughout.
##
## Ground dust thrown out sideways from an impact and left to hang. `strength`
## scales reach and count; `wide` spreads the source along the floor for the
## titan's feet rather than a single stone.
static func dust_burst(parent: Node, at: Vector2, strength := 1.0,
		wide := false, z := 0) -> CPUParticles2D:
	var dust := _emitter(parent, at, z)
	dust.texture = soft_texture()
	dust.amount = int(lerpf(14.0, 34.0, clampf(strength - 0.4, 0.0, 1.0))) + (12 if wide else 0)
	dust.lifetime = 1.15 + strength * 0.35
	dust.explosiveness = 0.92
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2((54.0 if wide else 16.0) * strength, 3.0)
	dust.direction = Vector2(0, -1)
	dust.spread = 82.0
	dust.gravity = Vector2(0, -26.0)
	dust.initial_velocity_min = 55.0 * strength
	dust.initial_velocity_max = 170.0 * strength
	dust.damping_min = 90.0
	dust.damping_max = 150.0
	dust.scale_amount_min = 0.55 * strength
	dust.scale_amount_max = 1.35 * strength
	dust.scale_amount_curve = _curve([[0.0, 0.35], [0.3, 1.0], [1.0, 1.55]])
	dust.color_ramp = _ramp([[0.0, DUST_LIT, 0.85], [0.35, DUST_MID, 0.62], [1.0, DUST_DARK, 0.0]])
	dust.angle_min = -180.0
	dust.angle_max = 180.0
	_fire(dust)
	return dust


## A slow column rising off a heavy hit, behind the sideways burst: the part
## that is still in the air a second later and tells you something big landed.
static func dust_plume(parent: Node, at: Vector2, strength := 1.0, z := 0) -> CPUParticles2D:
	var plume := _emitter(parent, at, z)
	plume.texture = soft_texture()
	plume.amount = int(10.0 + 10.0 * strength)
	plume.lifetime = 1.9
	plume.explosiveness = 0.7
	plume.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	plume.emission_rect_extents = Vector2(22.0 * strength, 4.0)
	plume.direction = Vector2(0, -1)
	plume.spread = 24.0
	plume.gravity = Vector2(0, -38.0)
	plume.initial_velocity_min = 40.0
	plume.initial_velocity_max = 95.0 * strength
	plume.damping_min = 40.0
	plume.damping_max = 70.0
	plume.scale_amount_min = 0.9 * strength
	plume.scale_amount_max = 1.7 * strength
	plume.scale_amount_curve = _curve([[0.0, 0.4], [0.5, 1.1], [1.0, 1.6]])
	plume.color_ramp = _ramp([[0.0, DUST_MID, 0.55], [0.5, DUST_DARK, 0.32], [1.0, DUST_DARK, 0.0]])
	plume.angle_min = -180.0
	plume.angle_max = 180.0
	_fire(plume)
	return plume


## Stone chips knocked loose. Real sprites off the rock sheet, tumbling under
## gravity, so they are unmistakably pieces of the thing that broke.
static func debris_burst(parent: Node, at: Vector2, count: int, strength := 1.0,
		dirt := false, z := 0, upward := 1.0) -> CPUParticles2D:
	var regions: Array = DIRT_CHIPS if dirt else GREY_CHIPS
	var chips := _emitter(parent, at, z)
	chips.texture = chip_texture(regions[randi() % regions.size()])
	chips.amount = maxi(count, 1)
	# Short: with no collision the chips would otherwise carry on down through
	# the floor tiles, and a chip under the floor gives the trick away.
	chips.lifetime = 0.28 + 0.3 * strength
	chips.explosiveness = 1.0
	chips.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	chips.emission_rect_extents = Vector2(10.0 * strength, 2.0)
	chips.direction = Vector2(0, -1)
	chips.spread = 62.0
	chips.gravity = Vector2(0, 1700.0)
	chips.initial_velocity_min = 300.0 * strength * upward
	chips.initial_velocity_max = 440.0 * strength * upward
	chips.angular_velocity_min = -540.0
	chips.angular_velocity_max = 540.0
	chips.scale_amount_min = 0.16 * strength
	chips.scale_amount_max = 0.34 * strength
	chips.color_ramp = _ramp([[0.0, Color.WHITE, 1.0], [0.45, Color.WHITE, 1.0], [0.75, Color(0.6, 0.6, 0.6), 0.0]])
	_fire(chips)
	return chips


## The room is lit by torches, so a hard hit throws a few embers along with the
## grit - a cheap way to give the flash some weight without any lighting.
static func spark_burst(parent: Node, at: Vector2, count: int, strength := 1.0, z := 0) -> CPUParticles2D:
	var sparks := _emitter(parent, at, z)
	sparks.texture = soft_texture()
	sparks.amount = maxi(count, 1)
	sparks.lifetime = 0.5
	sparks.explosiveness = 1.0
	sparks.direction = Vector2(0, -1)
	sparks.spread = 75.0
	sparks.gravity = Vector2(0, 900.0)
	sparks.initial_velocity_min = 260.0 * strength
	sparks.initial_velocity_max = 620.0 * strength
	sparks.scale_amount_min = 0.1
	sparks.scale_amount_max = 0.22
	sparks.scale_amount_curve = _curve([[0.0, 1.0], [1.0, 0.1]])
	sparks.color_ramp = _ramp([[0.0, Color(1.0, 0.95, 0.7), 1.0], [0.4, EMBER, 1.0], [1.0, Color(0.5, 0.12, 0.02), 0.0]])
	_fire(sparks)
	return sparks


## A continuous dust wake for something moving: a stone in flight or a wave
## crossing the floor. Particles are left in world space so the trail stays
## behind the thing that made it.
static func trail(parent: Node, rate := 26, z := 0) -> CPUParticles2D:
	var wake := _emitter(parent, Vector2.ZERO, z)
	wake.local_coords = false
	wake.texture = soft_texture()
	wake.amount = rate
	wake.lifetime = 0.55
	wake.explosiveness = 0.0
	wake.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	wake.emission_sphere_radius = 6.0
	wake.direction = Vector2(0, -1)
	wake.spread = 180.0
	wake.gravity = Vector2(0, -20.0)
	wake.initial_velocity_min = 8.0
	wake.initial_velocity_max = 34.0
	wake.scale_amount_min = 0.35
	wake.scale_amount_max = 0.7
	wake.scale_amount_curve = _curve([[0.0, 0.5], [1.0, 1.4]])
	wake.color_ramp = _ramp([[0.0, DUST_LIT, 0.55], [1.0, DUST_MID, 0.0]])
	wake.emitting = true
	return wake


## Pebbles hopping on the spot: the floor trembling before something comes up
## through it, or under a foot about to come down.
static func tremor(parent: Node, at: Vector2, width: float, z := 0) -> CPUParticles2D:
	var pebbles := _emitter(parent, at, z)
	pebbles.texture = chip_texture(GREY_CHIPS[0])
	pebbles.amount = 10
	pebbles.lifetime = 0.3
	pebbles.explosiveness = 0.0
	pebbles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	pebbles.emission_rect_extents = Vector2(width, 1.0)
	pebbles.direction = Vector2(0, -1)
	pebbles.spread = 16.0
	pebbles.gravity = Vector2(0, 1500.0)
	pebbles.initial_velocity_min = 140.0
	pebbles.initial_velocity_max = 260.0
	pebbles.angular_velocity_min = -400.0
	pebbles.angular_velocity_max = 400.0
	pebbles.scale_amount_min = 0.12
	pebbles.scale_amount_max = 0.24
	pebbles.emitting = true
	return pebbles


## Stop a continuous emitter and let what it has already thrown finish, then
## take it out. For wakes handed off by something that is about to be freed.
static func release(particles: Variant) -> void:
	if particles == null or not is_instance_valid(particles):
		return
	particles.emitting = false
	particles.one_shot = true
	particles.finished.connect(particles.queue_free)
	# Belt and braces: `finished` only fires for a shot that was one-shot from
	# the start in some versions, so a timer under the emitter backs it up and
	# goes with it whichever way it leaves.
	var backstop := Timer.new()
	backstop.one_shot = true
	backstop.wait_time = particles.lifetime + 0.5
	backstop.timeout.connect(particles.queue_free)
	particles.add_child(backstop)
	backstop.start()


## Advance an emitter by the world's clock rather than the frame's. Untyped
## on purpose: a one-shot frees itself when it is done, and a stale reference
## to it must be a no-op rather than a type error.
static func tick(particles: Variant, world_scale: float) -> void:
	if particles != null and is_instance_valid(particles):
		particles.speed_scale = world_scale


static func _emitter(parent: Node, at: Vector2, z: int) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	particles.z_index = z
	particles.emitting = false
	particles.randomness = 0.9
	parent.add_child(particles)
	particles.global_position = at
	return particles


## Burst once and take yourself out afterwards, so callers can fire and forget.
static func _fire(particles: CPUParticles2D) -> void:
	particles.one_shot = true
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


static func _curve(points: Array) -> Curve:
	var curve := Curve.new()
	for point: Array in points:
		curve.add_point(Vector2(point[0], point[1]))
	return curve


static func _ramp(stops: Array) -> Gradient:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for stop: Array in stops:
		offsets.append(stop[0])
		var color: Color = stop[1]
		color.a = stop[2]
		colors.append(color)
	gradient.offsets = offsets
	gradient.colors = colors
	return gradient
