extends Node
## Owns the flow of time for everything except the player.
##
## Engine.time_scale is deliberately not used: the player must keep moving at
## full speed while the world is stopped or slowed. Instead the world advances
## on `world_delta()`, and any node that should obey time powers asks for its
## delta here rather than using the raw frame delta.
##
## It also keeps the recent past. Anything in the `rewindable` group is
## snapshotted every physics tick - the boy included, this once - and a rewind
## plays those snapshots back in reverse while the forward simulation is held
## still. See `Mode.REWINDING` below.
##
## A body that would normally free itself (a unit whose dying clip has ended, a
## round that found its mark) asks `retire()` instead: it is hidden and kept for
## as long as the buffer reaches back, so that a rewind can stand it up again.

enum Mode { NORMAL, STOPPED, SLOWED, REWINDING }

const SLOW_SCALE := 0.25

## How far back one rewind reaches, in seconds of what actually happened on
## screen, and how much faster than that it runs back. Four seconds is long
## enough to take back a missed jump or the hit before this one; at 2.5x the
## whole thing is over in 1.6 s, quick enough that the world going backwards
## reads as a shove rather than a replay.
const REWIND_SPAN := 4.0
const REWIND_SPEED := 2.5
## Kept a little past the span: the flourish runs on forward time before the
## rewind engages, and the window is measured from the moment it lands.
const HISTORY_KEPT := REWIND_SPAN + 1.0

const REWINDABLE_GROUP := &"rewindable"

## Loaded by path rather than by class name: an autoload is parsed before the
## global class list is, so the name alone is not enough here.
const GHOSTS := preload("res://src/world/effects/rewind_ghosts.gd")

## The recent past of one node. `frames` holds `[time, state]` pairs, oldest
## first, with `state` whatever the node's `rewind_capture()` returned.
class Track:
	var node: Node
	var frames: Array = []
	## History time at which the node retired, or negative while it is alive.
	var retired_at := -1.0

	func _init(p_node: Node) -> void:
		node = p_node

	## The latest snapshot taken at or before `time`, or empty if none.
	func frame_at(time: float) -> Array:
		for i in range(frames.size() - 1, -1, -1):
			if frames[i][0] <= time:
				return frames[i]
		return []


var mode: Mode = Mode.NORMAL:
	set = _set_mode

## Multiplier applied to world time.
var world_scale := 1.0

## The history clock, in real seconds since the level started. Runs forward
## while the world is recorded and backward while it is being rewound.
var _now := 0.0
var _rewind_from := 0.0
## Keyed by instance id rather than by the node itself, the way Hazard keeps its
## cooldowns: a typed Node key rejects every read once that node is freed.
var _tracks: Dictionary[int, Track] = {}
var _ghosts: Node2D = null

func world_delta(delta: float) -> float:
	return delta * world_scale


func is_world_frozen() -> bool:
	return is_zero_approx(world_scale)


func is_rewinding() -> bool:
	return mode == Mode.REWINDING


## Whether the past is being kept at all. Only once the boy has the power: a
## phase without it should run exactly as it always has, retired bodies included.
func is_recording() -> bool:
	return GameState.has_ability(GameState.ABILITY_REWIND)


## A death choice should only offer Rewind if its destination restores health.
## Include the cast windup: that much forward time passes before playback starts.
func can_restore_player(player: Node, windup: float) -> bool:
	var track: Track = _tracks.get(player.get_instance_id())
	if track == null or track.frames.is_empty():
		return false
	var destination := maxf(_now + windup - REWIND_SPAN, track.frames[0][0])
	var frame := track.frame_at(destination)
	# Player.rewind_capture stores health at index 5.
	return not frame.is_empty() and frame[1][5] > 0.0


func reset() -> void:
	_set_mode(Mode.NORMAL)
	_now = 0.0
	_tracks.clear()
	if _ghosts != null and is_instance_valid(_ghosts):
		_ghosts.queue_free()
	_ghosts = null


## One-way room transitions cannot restore their old gate state. Discard that
## history and its retired bodies together; otherwise reset would register a
## hidden corpse as a live track and let a later rewind resurrect it.
func start_history_window() -> void:
	for track in _tracks.values():
		if track.retired_at >= 0.0 and is_instance_valid(track.node):
			track.node.queue_free()
	reset()


## What a rewindable node calls instead of `queue_free()` when it is done. With
## nothing recording it is exactly that; otherwise the node is hidden and kept
## until its last snapshot has aged out of the buffer.
func retire(node: Node) -> void:
	if not is_recording() or not _tracks.has(node.get_instance_id()):
		node.queue_free()
		return
	var track := _tracks[node.get_instance_id()]
	if track.retired_at >= 0.0:
		return
	track.retired_at = _now
	node.rewind_retire()


func _physics_process(delta: float) -> void:
	if mode == Mode.REWINDING:
		_play_back(delta)
		return
	if not is_recording():
		return
	_now += delta
	_record()


func _record() -> void:
	for node in get_tree().get_nodes_in_group(REWINDABLE_GROUP):
		var id := node.get_instance_id()
		if not _tracks.has(id):
			_tracks[id] = Track.new(node)
		var track := _tracks[id]
		if track.retired_at >= 0.0:
			continue
		track.frames.append([_now, node.rewind_capture()])

	var horizon := _now - HISTORY_KEPT
	for id in _tracks.keys():
		var track: Track = _tracks[id]
		if not is_instance_valid(track.node):
			_tracks.erase(id)
			continue
		while not track.frames.is_empty() and track.frames[0][0] < horizon:
			track.frames.pop_front()
		# A retired body whose whole past has aged out can no longer be brought
		# back, so it finally goes.
		if track.retired_at >= 0.0 and track.retired_at < horizon:
			_tracks.erase(id)
			track.node.queue_free()


func _play_back(delta: float) -> void:
	# No further back than the span, and no further back than anything was
	# recorded: past the oldest snapshot there is nothing to show, and a track
	# with no frame at all is what `_end_rewind` reads as "never existed".
	var floor_time := maxf(_rewind_from - REWIND_SPAN, _oldest_recorded())
	_now = maxf(_now - delta * REWIND_SPEED, floor_time)
	for id in _tracks.keys():
		var track: Track = _tracks[id]
		if not is_instance_valid(track.node):
			_tracks.erase(id)
			continue
		# Already gone at this point in the past: it stays gone.
		if track.retired_at >= 0.0 and _now >= track.retired_at:
			continue
		var frame := track.frame_at(_now)
		if frame.is_empty():
			# Not born yet - a round fired inside the window goes back into the
			# barrel. Retired for now; freed when the rewind lets go.
			track.node.rewind_retire()
			continue
		track.node.rewind_apply(frame[1])
	if _ghosts != null:
		_ghosts.stamp(_live_nodes())


func _begin_rewind() -> void:
	_rewind_from = _now
	for track in _tracks.values():
		if is_instance_valid(track.node) and track.node.has_method(&"rewind_began"):
			track.node.rewind_began()
	var scene := get_tree().current_scene
	if scene != null:
		_ghosts = GHOSTS.new()
		scene.add_child(_ghosts)


## The rewind has let go. Whatever lay ahead of this moment never happened now:
## the future is cut off every track, a body that had not been born yet goes,
## and one that had died since gets its life back.
func _end_rewind() -> void:
	for id in _tracks.keys():
		var track: Track = _tracks[id]
		if not is_instance_valid(track.node):
			_tracks.erase(id)
			continue
		while not track.frames.is_empty() and track.frames[-1][0] > _now:
			track.frames.pop_back()
		if track.frames.is_empty():
			_tracks.erase(id)
			track.node.queue_free()
			continue
		if track.retired_at >= 0.0 and track.retired_at > _now:
			track.retired_at = -1.0
			if track.node.is_in_group(&"enemy"):
				EventBus.enemy_revived.emit(track.node)
	for track in _tracks.values():
		if track.node.has_method(&"rewind_ended"):
			track.node.rewind_ended()
	if _ghosts != null:
		_ghosts.finish()
		_ghosts = null


func _oldest_recorded() -> float:
	var oldest := INF
	for track in _tracks.values():
		if not track.frames.is_empty():
			oldest = minf(oldest, track.frames[0][0])
	return 0.0 if oldest == INF else oldest


func _live_nodes() -> Array[Node]:
	var live: Array[Node] = []
	for track in _tracks.values():
		if is_instance_valid(track.node) and (track.retired_at < 0.0 or _now < track.retired_at) \
				and not track.frame_at(_now).is_empty():
			live.append(track.node)
	return live


func _set_mode(value: Mode) -> void:
	if mode == value:
		return
	var was_rewinding := mode == Mode.REWINDING
	mode = value
	match mode:
		Mode.NORMAL: world_scale = 1.0
		Mode.SLOWED: world_scale = SLOW_SCALE
		Mode.STOPPED, Mode.REWINDING: world_scale = 0.0
	if mode == Mode.REWINDING:
		_begin_rewind()
	elif was_rewinding:
		_end_rewind()
	EventBus.time_mode_changed.emit(mode)
