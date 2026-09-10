extends Hazard
## Live electricity stays dangerous and animated, even while world time is stopped.
@export_range(1.0, 60.0, 1.0) var animation_fps := 16.0:
	set(value):
		animation_fps = clampf(value, 1.0, 60.0)
		_apply_animation_speed()

var _frame_progress := 0.0

func _ready() -> void:
	super()
	_apply_animation_speed()
	var emitter := get_node_or_null(^"Emitter")
	if emitter is AnimatedSprite2D:
		emitter.play(&"electricity")
	elif emitter is Sprite2D:
		_frame_progress = float(emitter.frame)

func _apply_animation_speed() -> void:
	var emitter := get_node_or_null(^"Emitter")
	if emitter is AnimatedSprite2D and emitter.sprite_frames != null:
		emitter.sprite_frames.set_animation_speed(&"electricity", animation_fps)

func _physics_process(delta: float) -> void:
	super(delta)
	# The live electrical sound must continue alongside its animation during time stop.
	if _audio != null:
		_audio.stream_paused = false
	var emitter := get_node_or_null(^"Emitter")
	if emitter is AnimatedSprite2D:
		# Electricity remains live, so its animation must not suggest a safe freeze.
		emitter.speed_scale = 1.0
	elif emitter is Sprite2D:
		# Older editor buffers still contain the original four-frame sprite sheet.
		# Animate it directly so those instances work without discarding local edits.
		var frame_count: int = emitter.hframes * emitter.vframes
		_frame_progress = fposmod(_frame_progress + delta * animation_fps, frame_count)
		emitter.frame = int(_frame_progress)
