extends Hazard
## Live electricity stays dangerous and animated, even while world time is
## stopped - and now stays hidden below the floor until the boy is close
## enough to catch, so this patch of ground is the actual threat rather than
## a permanently-sparking landmark he can just route around.
##
## ProximityZone (bigger than the damage Shape) is what notices him coming;
## the short warning beat is the only telegraph before it punches up, and the
## punch itself is deliberately much quicker than a platform's ease so it
## reads as a strike rather than a rising deck.
@export_range(1.0, 60.0, 1.0) var animation_fps := 16.0:
	set(value):
		animation_fps = clampf(value, 1.0, 60.0)
		_apply_animation_speed()

## Seconds the skull gets to flash before the spark actually breaks the floor.
@export var warning_time := 0.15
## The punch itself, up and back down - fast on purpose: see the class doc.
@export var emerge_time := 0.1
@export var retract_time := 0.1
## How far below its resting spot the emitter parks while hidden - enough
## that no part of the sprite peeks over the floor line.
@export var hidden_drop := 56.0

enum State { HIDDEN, WARNING, EMERGING, ACTIVE, RETRACTING }

var _frame_progress := 0.0
var _state := State.HIDDEN
var _elapsed := 0.0
var _rest_position := Vector2.ZERO
## Bodies currently inside ProximityZone, tracked by count rather than a
## single flag so one thing leaving early cannot retract the trap out from
## under another that is still standing in it.
var _near_count := 0

@onready var _emitter: Node2D = get_node_or_null(^"Emitter")
@onready var _warning_sign: CanvasItem = get_node_or_null(^"WarningSign")
@onready var _shape: CollisionShape2D = get_node_or_null(^"Shape")
@onready var _proximity: Area2D = get_node_or_null(^"ProximityZone")


func _ready() -> void:
	super()
	_apply_animation_speed()
	if _emitter is AnimatedSprite2D:
		_emitter.play(&"electricity")
	elif _emitter is Sprite2D:
		_frame_progress = float(_emitter.frame)
	if _emitter != null:
		_rest_position = _emitter.position
	if _proximity != null:
		_proximity.body_entered.connect(_on_proximity_entered)
		_proximity.body_exited.connect(_on_proximity_exited)
	_snap_hidden()


func _apply_animation_speed() -> void:
	if _emitter is AnimatedSprite2D and _emitter.sprite_frames != null:
		_emitter.sprite_frames.set_animation_speed(&"electricity", animation_fps)


func _on_proximity_entered(body: Node2D) -> void:
	if not (body is Player):
		return
	_near_count += 1
	if _state == State.HIDDEN:
		_begin_warning()
	elif _state == State.RETRACTING:
		# Walked back in before it finished hiding - straight back to danger
		# rather than finishing a retreat he is already reversing.
		_snap_active()


func _on_proximity_exited(body: Node2D) -> void:
	if not (body is Player):
		return
	_near_count = maxi(_near_count - 1, 0)
	if _near_count == 0 and _state in [State.WARNING, State.EMERGING, State.ACTIVE]:
		_begin_retracting()


func _snap_hidden() -> void:
	_state = State.HIDDEN
	_elapsed = 0.0
	if _warning_sign != null:
		_warning_sign.visible = false
	if _emitter != null:
		_emitter.visible = false
		_emitter.position = _rest_position + Vector2(0, hidden_drop)
	if _shape != null:
		_shape.set_deferred(&"disabled", true)
	monitoring = false
	if _audio != null:
		_audio.stop()


func _begin_warning() -> void:
	_state = State.WARNING
	_elapsed = 0.0
	if _warning_sign != null:
		_warning_sign.visible = true


func _begin_emerging() -> void:
	_state = State.EMERGING
	_elapsed = 0.0
	if _warning_sign != null:
		_warning_sign.visible = false
	if _emitter != null:
		_emitter.visible = true
	if _audio != null:
		_audio.play()


## Reached either by finishing the punch-up or by being caught mid-retreat -
## both land in the same fully-live state, so there is only one "on".
func _snap_active() -> void:
	_state = State.ACTIVE
	_elapsed = 0.0
	if _warning_sign != null:
		_warning_sign.visible = false
	if _emitter != null:
		_emitter.visible = true
		_emitter.position = _rest_position
	if _shape != null:
		_shape.set_deferred(&"disabled", false)
	monitoring = true
	if _audio != null and not _audio.playing:
		_audio.play()


func _begin_retracting() -> void:
	_state = State.RETRACTING
	_elapsed = 0.0
	if _shape != null:
		_shape.set_deferred(&"disabled", true)
	monitoring = false


func _physics_process(delta: float) -> void:
	super(delta)
	# The live electrical sound must continue alongside its animation during time stop.
	if _audio != null:
		_audio.stream_paused = false
	if _emitter is AnimatedSprite2D:
		# Electricity remains live, so its animation must not suggest a safe freeze.
		_emitter.speed_scale = 1.0
	elif _emitter is Sprite2D:
		# Older editor buffers still contain the original four-frame sprite sheet.
		# Animate it directly so those instances work without discarding local edits.
		var frame_count: int = _emitter.hframes * _emitter.vframes
		_frame_progress = fposmod(_frame_progress + delta * animation_fps, frame_count)
		_emitter.frame = int(_frame_progress)

	# Real frame time, not TimeService.world_delta(): the ground does not care
	# that the boy stopped the clock, the same reason the animation and sound
	# above never do either. Approaching this patch with time held still is
	# still the mistake it would be at full speed.
	_elapsed += delta
	match _state:
		State.WARNING:
			if _elapsed >= warning_time:
				_begin_emerging()
		State.EMERGING:
			var t := clampf(_elapsed / emerge_time, 0.0, 1.0)
			if _emitter != null:
				_emitter.position.y = lerpf(_rest_position.y + hidden_drop, _rest_position.y, t)
			if t >= 1.0:
				_snap_active()
		State.RETRACTING:
			var t := clampf(_elapsed / retract_time, 0.0, 1.0)
			if _emitter != null:
				_emitter.position.y = lerpf(_rest_position.y, _rest_position.y + hidden_drop, t)
			if t >= 1.0:
				_snap_hidden()
