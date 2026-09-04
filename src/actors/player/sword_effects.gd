class_name SwordEffects
extends Node2D
## The swing you can actually see. Drawn rather than authored, so it needs no
## art: a tapered crescent following the blade through its arc, and a burst of
## sparks wherever it lands.
##
## Two separate readings, because a swing and a hit are different information.
## The crescent fires on every swing, hit or miss, so the attack always shows.
## The burst only fires where the blade found something, so connecting looks
## different from swinging at air - which, before this, it did not.
##
## Ticks on the raw frame delta. The boy is exempt from his own time powers, so
## his sword is too: a swing while the world is held still still flashes.

## How far the crescent reaches and where it is hinged, both measured off the
## swing that Player.perform_attack_hit already tests - 78px forward of him,
## a little over half his 100px height up from his feet.
const REACH := 84.0
const INNER := 40.0
const PIVOT := Vector2(0.0, -56.0)
## The arc is flattened, because he swings across the screen rather than around
## a circle. Without this the top of it clears his own head by half his height.
const SQUASH := 0.82

## The arc the blade covers, in radians from straight ahead: starting high
## behind the shoulder, finishing low in front.
const SWING_FROM := -2.0
const SWING_TO := 0.7
## How far the trailing edge lags the blade, as a fraction of the swing.
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


## One swing, wherever he was standing when the blade came round.
func slash(at: Vector2, facing: int) -> void:
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
		_draw_slash(slash_effect)
	for impact_effect in _impacts:
		_draw_impact(impact_effect)


func _draw_slash(effect: Dictionary) -> void:
	var progress: float = clampf(effect["age"] / SLASH_LIFE, 0.0, 1.0)
	var centre: Vector2 = effect["at"] + PIVOT
	var facing: int = effect["facing"]
	# The blade leads and the trail chases it, so the crescent is a shape being
	# drawn rather than a shape being faded in.
	var head := _ease(progress)
	var tail := _ease(maxf(progress - TRAIL, 0.0) / (1.0 - TRAIL))
	if head <= tail:
		return
	var fade := 1.0 - progress * progress

	var steps := 14
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in steps + 1:
		var along := float(i) / steps
		var angle := _facing_angle(lerpf(SWING_FROM, SWING_TO, lerpf(tail, head, along)), facing)
		var edge := Vector2.from_angle(angle)
		edge.y *= SQUASH
		# Fattest at the blade, tapering to nothing at the tail.
		outer.append(centre + edge * REACH)
		inner.append(centre + edge * lerpf(REACH, INNER, lerpf(0.15, 1.0, along)))
	inner.reverse()
	draw_colored_polygon(outer + inner, Color(BODY, 0.5 * fade))
	draw_polyline(outer, Color(EDGE, 0.95 * fade), 3.0, true)


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


## Mirrors the swing for a boy facing left. `flip_h` only mirrors his texture;
## anything drawn here has to be turned by hand.
func _facing_angle(angle: float, facing: int) -> float:
	return angle if facing >= 0 else PI - angle


## Fast out of the gate, easing into the follow-through - how a swing moves.
func _ease(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 2.5)
