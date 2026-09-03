class_name MovingHazard
extends Hazard
## A Hazard that patrols a straight line instead of sitting still. Everything
## about the damage volume is inherited untouched - this only drives position.
##
## The two ends are the node's placed position and that position plus `travel`,
## so a saw is authored by dropping it at one end and dialling in the offset.
## Leaving `travel` at zero parks it, which keeps this usable as a drop-in
## replacement for a plain Hazard.
##
## Movement runs on TimeService's clock rather than the raw frame delta, so a
## saw freezes with the rest of the world when the boy stops time. The damage
## volume stays live while it is frozen: a stopped blade still cuts.

## Offset from the placed position to the far end of the patrol, in pixels.
@export var travel := Vector2(240.0, 0.0)

## Pixels per second along that line.
@export var speed := 90.0

## Starting point on the line: 0 at the placed position, 1 at the far end.
## Lets several hazards share a rhythm without moving in lockstep.
@export_range(0.0, 1.0) var start_at := 0.0

var _origin: Vector2
var _progress := 0.0
var _direction := 1.0

func _ready() -> void:
	super()
	_origin = position
	_progress = clampf(start_at, 0.0, 1.0)
	# Starting parked at the far end has to head back, or it would stall there.
	_direction = -1.0 if is_equal_approx(_progress, 1.0) else 1.0
	position = _origin + travel * _progress


func _physics_process(delta: float) -> void:
	super(delta)
	var length := travel.length()
	# A parked saw is a silent one.
	if is_zero_approx(length) or is_zero_approx(speed):
		if _audio != null and _audio.playing:
			_audio.stop()
		return
	# Hazard pauses the stream while the world is stopped, and a paused player
	# reports `playing == false`. Without the second test that reads as "the
	# loop ran out, start it again", which un-pauses the saw the instant the
	# boy freezes time - the one moment it is supposed to go quiet.
	if _audio != null and not _audio.playing and not _audio.stream_paused:
		_audio.play()
	_progress += _direction * TimeService.world_delta(delta) * speed / length
	if _progress >= 1.0:
		_progress = 1.0
		_direction = -1.0
	elif _progress <= 0.0:
		_progress = 0.0
		_direction = 1.0
	position = _origin + travel * _progress
