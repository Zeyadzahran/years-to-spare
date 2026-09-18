class_name HeartPickup
extends Area2D
## A heart on the ground: one more try, picked up by walking into it. The same
## shape as the fig (pickup.gd) - nothing to press, nothing to carry - but what
## it gives is a life, not health, so it answers to GameState rather than to
## the body that walked in, and the level remembers it was taken: a retry puts
## him back at the marker with the heart still gone, so a stretch with a heart
## on it cannot be died through for a free life each time.

## Packed inside something - a supply chest - rather than lying in the open:
## unseen and untouchable until whatever holds it calls `release()`, then it
## springs out and hovers above it to be picked up.
@export var stowed := false
## How likely this heart is to exist at all on a given run. The level rolls
## it once per run and removes the heart before the first frame if it lost,
## so a box may be full one playthrough and empty the next - and a retry
## within the run finds it the way it was.
@export_range(0.0, 1.0, 0.05) var chance := 1.0

## Where a released heart settles, relative to where it was stowed: clear of
## the chest lid and level with his chest, so walking up to the box takes it.
const REST := Vector2(0.0, -56.0)
## How high the spring carries it before it drops back to rest.
const SPRING := Vector2(0.0, -110.0)

## Reported to the level the moment it was taken, so a rewind that puts it
## back can say so too. Separate from `_collected` because a rewind may put
## the heart back while its sound is still playing.
var _reported := false
## Taken or not. Kept as its own flag rather than read off `monitoring`, which
## a rewind sets deferred and so lags a frame.
var _collected := false
## Out of its chest. Always true for a heart that was never stowed.
var _released := false
var _origin := Vector2.ZERO
var _spring: Tween

func _ready() -> void:
	add_to_group(TimeService.REWINDABLE_GROUP)
	add_to_group(&"heart_pickup")
	$PickupAudio.finished.connect(_on_audio_finished)
	EventBus.player_hearts_changed.connect(_on_hearts_changed)
	_origin = position
	_released = not stowed
	if stowed:
		_stow()
	else:
		_on_hearts_changed(GameState.hearts, GameState.HEART_CAP)


## Back in the box: unseen, untouchable, and where it started.
func _stow() -> void:
	if _spring != null and _spring.is_valid():
		_spring.kill()
	visible = false
	set_deferred(&"monitoring", false)
	set_physics_process(false)
	position = _origin


## The chest has opened: spring out and settle above it. It cannot be taken
## on the way up - it would pass straight through whoever opened the box -
## only once it has landed.
func release() -> void:
	if _released:
		return
	_released = true
	position = _origin
	_on_hearts_changed(GameState.hearts, GameState.HEART_CAP)
	_spring = create_tween()
	_spring.tween_property(self, ^"position", _origin + SPRING, 0.28) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_spring.tween_property(self, ^"position", _origin + REST, 0.22) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_spring.finished.connect(_land)


func _land() -> void:
	if _collected or not _released:
		return
	set_deferred(&"monitoring", true)
	set_physics_process(true)


## A heart at the cap would be a no-op in _take() below; this keeps it out of
## sight to match, and brings it back the moment it would actually count.
## `_collected` guards a heart mid-collection from being shown again, and a
## stowed one stays in its box regardless.
func _on_hearts_changed(current: int, heart_cap: int) -> void:
	if _collected or not _released:
		return
	visible = current < heart_cap


## Overlap is polled rather than taken off `body_entered`, the way the fig
## does: a boy standing on a heart at the cap who then loses one has already
## entered, and the heart would sit under his feet until he stepped off and on.
func _physics_process(_delta: float) -> void:
	if TimeService.is_rewinding():
		return
	for body in get_overlapping_bodies():
		if _take(body):
			return


func _take(body: Node2D) -> bool:
	if not (body is Player) or not body.health.is_alive():
		return false
	# Left where it is for when it would count. Walking over a heart at the
	# cap should not quietly waste it.
	if GameState.hearts >= GameState.HEART_CAP:
		return false
	GameState.gain_heart()
	_collected = true
	_reported = true
	EventBus.heart_collected.emit(self)
	$PickupAudio.play()
	visible = false
	set_physics_process(false)
	monitoring = false
	return true


## Retired rather than freed once the sound is done, so a rewind past the
## moment he took it can put the heart back. A rewind may already have done so
## while the sound played, in which case it is on the ground and stays there.
func _on_audio_finished() -> void:
	if _collected:
		TimeService.retire(self)


func rewind_capture() -> Array:
	return [visible, _collected, _released]


func rewind_apply(saved: Array) -> void:
	visible = saved[0]
	_collected = saved[1]
	_released = saved[2]
	process_mode = Node.PROCESS_MODE_INHERIT
	if not _released:
		_stow()
		return
	# Out of its box: wherever the spring had it, it is settled now.
	if _spring != null and _spring.is_valid():
		_spring.kill()
	if stowed:
		position = _origin + REST
	set_deferred(&"monitoring", not _collected)
	set_physics_process(not _collected)


func rewind_retire() -> void:
	visible = false
	set_deferred(&"monitoring", false)
	set_physics_process(false)
	process_mode = Node.PROCESS_MODE_DISABLED


## The rewind has let go. If it reached back past the pickup, the heart is on
## the ground again and the level's record of it has to say so - or the next
## retry would remove a heart that is visibly there. The life it gave is not
## taken back, the same way a revived unit keeps the years its death paid out.
func rewind_ended() -> void:
	if _reported and not _collected:
		_reported = false
		EventBus.heart_restored.emit(self)
