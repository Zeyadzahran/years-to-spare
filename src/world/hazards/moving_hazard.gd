class_name MovingHazard
extends Hazard

@export var travel := Vector2(240.0, 0.0)
@export var speed := 90.0
@export_range(0.0, 1.0) var start_at := 0.0

var _origin: Vector2
var _progress := 0.0
var _direction := 1.0

@onready var _audio: AudioStreamPlayer2D = get_node_or_null("SawAudio")


func _ready() -> void:
	super()

	_origin = position
	_progress = clampf(start_at, 0.0, 1.0)
	_direction = -1.0 if is_equal_approx(_progress, 1.0) else 1.0
	position = _origin + travel * _progress


func _physics_process(delta: float) -> void:
	super(delta)

	var length := travel.length()

	if is_zero_approx(length) or is_zero_approx(speed):
		if _audio and _audio.playing:
			_audio.stop()
		return

	if _audio and not _audio.playing:
		_audio.play()

	_progress += _direction * TimeService.world_delta(delta) * speed / length

	if _progress >= 1.0:
		_progress = 1.0
		_direction = -1.0
	elif _progress <= 0.0:
		_progress = 0.0
		_direction = 1.0

	position = _origin + travel * _progress
