class_name SwordEffects
extends Node2D
## The swing you can actually see. Drawn rather than authored, so it needs no
## art: a lance of light running out along the blade, and a burst of sparks
## wherever it lands.
##
## It is a lance and not an arc because that is what the animation does. The
## attack frames hold the sword level at chest height and push it straight out -
## a thrust, not an overhead cut - so an arc swept past him instead of following
## the blade.
##
## Two separate readings, because a swing and a hit are different information.
## The crescent fires on every swing, hit or miss, so the attack always shows.
## The burst only fires where the blade found something, so connecting looks
## different from swinging at air - which, before this, it did not.
##
## Ticks on the raw frame delta. The boy is exempt from his own time powers, so
## his sword is too: a swing while the world is held still still flashes.

## Where the blade actually goes, measured off the attack frames rather than
## guessed. Node space, from his feet: the tip sits between y -70 and -80 across
## the thrust, and reaches the right edge of the 256px canvas on frames 3 and 4 -
## which is to say the art is cropped there, the same way the Gunner's muzzle
## flash is. The lance carries on to where the hit is actually tested (78px) and
## a little past, since that is the reach the blade would have had.
const THRUST_Y := -74.0
const THRUST_FROM := 26.0
const THRUST_TO := 126.0
## Half-height of the lance at its widest.
const THRUST_HALF := 14.0
## Where the shoulders of the spearhead sit, as a fraction back from its point.
const HEAD_LEN := 0.34
## How far the back of the lance lags its point, as a fraction of the push.
const TRAIL := 0.34

## Spans the swing from the clip's first frame to a little past the moment the
## blade lands (AttackState.HIT_TIME, 0.22s), so the crescent is most of the way
## round at exactly the point the hit is tested rather than only starting there.
const SLASH_LIFE := 0.28
const IMPACT_LIFE := 0.26

## White-hot at the edge, the game's gold behind it.
const EDGE := Color(1.0, 0.98, 0.92)
const BODY := Color(1.0, 0.84, 0.48)

var _slashes: Array[Dictionary] = []
var _impacts: Array[Dictionary] = []

func _ready() -> void:
	# World space, not the boy's: a slash left behind should stay where it was
	# swung, and must not be mirrored a second time by his own flip.
	top_level = true
	# Absolute rather than relative to the boy, whose own z the level sets to 10:
	# the crescent goes over the world it is swung through - units, and the
	# foreground scenery at z 1 - wherever he is placed.
	z_as_relative = false
	z_index = 20


## One swing, from wherever he was standing when the blade went out.
func thrust(at: Vector2, facing: int) -> void:
	_slashes.append({"at": at, "facing": facing, "age": 0.0})


## One connection. `at` is the point of contact, not the enemy's feet.
func impact(at: Vector2) -> void:
	_impacts.append({"at": at, "age": 0.0, "spin": randf() * TAU})


func _process(delta: float) -> void:
	if _slashes.is_empty() and _impacts.is_empty():
		return
	for slash_effect in _slashes:
		slash_effect["age"] += delta
	for impact_effect in _impacts:
		impact_effect["age"] += delta
	_slashes = _slashes.filter(func(e): return e["age"] < SLASH_LIFE)
	_impacts = _impacts.filter(func(e): return e["age"] < IMPACT_LIFE)
	# Called on the frame the last one expires too, which is what clears it.
	queue_redraw()


func _draw() -> void:
	for slash_effect in _slashes:
		_draw_thrust(slash_effect)
	for impact_effect in _impacts:
		_draw_impact(impact_effect)


func _draw_thrust(effect: Dictionary) -> void:
	var progress: float = clampf(effect["age"] / SLASH_LIFE, 0.0, 1.0)
	var base: Vector2 = effect["at"]
	var facing: int = effect["facing"]
	# The point leads and the back of the lance chases it, so the shape is being
	# driven forward rather than simply appearing at full length.
	var head := lerpf(THRUST_FROM, THRUST_TO, _ease(progress))
	var tail := lerpf(THRUST_FROM, THRUST_TO, _ease(maxf(progress - TRAIL, 0.0) / (1.0 - TRAIL)))
	var length := head - tail
	if length < 1.0:
		return
	var fade := 1.0 - progress * progress
	# Thin while it is still short, so the first frames read as a point going
	# out rather than a slab appearing at the hilt.
	var half := THRUST_HALF * minf(length / 60.0, 1.0)
	var shoulder := head - length * HEAD_LEN

	draw_colored_polygon(PackedVector2Array([
		_point(base, facing, head, 0.0),
		_point(base, facing, shoulder, -half),
		_point(base, facing, tail, 0.0),
		_point(base, facing, shoulder, half),
	]), Color(BODY, 0.55 * fade))
	# The blade line itself: white, thin, straight down the middle.
	draw_line(_point(base, facing, tail, 0.0), _point(base, facing, head, 0.0),
		Color(EDGE, 0.95 * fade), 3.0, true)
	# A pair of streaks riding either side of the push.
	for side: float in [-1.0, 1.0]:
		var rise := half * 0.7 * side
		draw_line(_point(base, facing, lerpf(tail, head, 0.3), rise),
			_point(base, facing, head - length * 0.15, rise),
			Color(EDGE, 0.45 * fade), 1.5, true)


## A point on the blade line: `along` forward of him, `rise` off that line.
func _point(base: Vector2, facing: int, along: float, rise: float) -> Vector2:
	return base + Vector2(along * facing, THRUST_Y + rise)


func _draw_impact(effect: Dictionary) -> void:
	var progress: float = clampf(effect["age"] / IMPACT_LIFE, 0.0, 1.0)
	var at: Vector2 = effect["at"]
	var fade := 1.0 - progress
	var radius := lerpf(8.0, 46.0, _ease(progress))

	draw_arc(at, radius, 0.0, TAU, 28, Color(EDGE, 0.9 * fade * fade), lerpf(6.0, 1.0, progress), true)
	# Sparks, angled off a value fixed at impact so they do not shimmer.
	var spin: float = effect["spin"]
	for i in 7:
		var dir := Vector2.from_angle(spin + TAU * i / 7.0)
		draw_line(at + dir * radius * 0.55, at + dir * radius * 1.45,
			Color(BODY, 0.8 * fade), lerpf(4.0, 1.0, progress), true)
	# The moment of contact itself, gone almost before it registers.
	if progress < 0.45:
		draw_circle(at, lerpf(16.0, 0.0, progress / 0.45), Color(EDGE, 0.9))


## Fast out of the gate, easing into the follow-through - how a thrust moves.
func _ease(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 2.5)
