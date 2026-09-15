class_name RewindGhosts
extends Node2D
## The trail a rewound body leaves behind it. While time runs backward every
## tracked node is stamped a few times a second: a copy of whatever its sprite
## is showing, tinted cold and left where it was to fade. Read together they
## draw the path each thing is being dragged back along, which is what makes a
## rewind look like something being undone rather than bodies teleporting.
##
## Built by TimeService when a rewind lands and dropped into the level scene,
## the way a Gunner drops his rounds in; it frees itself once the rewind has
## let go and the last ghost has faded.

## Seconds between stamps, and how long each one lingers. Close enough together
## that a running body leaves an unbroken smear; short enough that the trail
## ends a beat behind the body rather than stretching across the whole screen.
const INTERVAL := 0.06
const LIFE := 0.35
## The colour of the past: cold, to match the overlay, and well under full
## alpha so the ghosts read as an echo and never as a second crowd.
const TINT := Color(0.62, 0.78, 1.0, 0.45)

var _since_stamp := INTERVAL
var _ghosts: Array[Dictionary] = []
var _finished := false

func _ready() -> void:
	top_level = true
	# Over the actors, at a fraction of their alpha: the body being rewound is
	# drawn through the echo it has just left, not behind it.
	z_index = 1


## Lays down a ghost of each of `nodes` if enough time has passed since the
## last set. Called every physics tick of the rewind; the interval is kept here.
func stamp(nodes: Array[Node]) -> void:
	_since_stamp += get_physics_process_delta_time()
	if _since_stamp < INTERVAL:
		return
	_since_stamp = 0.0
	for node in nodes:
		var source := _sprite_of(node)
		if source == null or not source.visible or not source.is_visible_in_tree():
			continue
		var ghost := _copy(source)
		if ghost == null:
			continue
		add_child(ghost)
		_ghosts.append({"sprite": ghost, "age": 0.0})


## No more stamps; the layer goes once the trail has faded.
func finish() -> void:
	_finished = true


func _process(delta: float) -> void:
	for i in range(_ghosts.size() - 1, -1, -1):
		var entry := _ghosts[i]
		entry["age"] += delta
		var sprite := entry["sprite"] as Sprite2D
		var left: float = 1.0 - entry["age"] / LIFE
		if left <= 0.0:
			sprite.queue_free()
			_ghosts.remove_at(i)
			continue
		sprite.modulate = Color(TINT, TINT.a * left)
	if _finished and _ghosts.is_empty():
		queue_free()


## The picture a node is currently showing: its first sprite child. The boy,
## the units and the rounds all keep theirs under `Sprite`; the decks keep
## `Art`. Searched rather than named so a new rewindable needs no wiring here.
func _sprite_of(node: Node) -> Node2D:
	for child in node.get_children():
		if child is AnimatedSprite2D or child is Sprite2D:
			return child
	return null


func _copy(source: Node2D) -> Sprite2D:
	var ghost := Sprite2D.new()
	if source is AnimatedSprite2D:
		var animated := source as AnimatedSprite2D
		if animated.sprite_frames == null or not animated.sprite_frames.has_animation(animated.animation):
			return null
		ghost.texture = animated.sprite_frames.get_frame_texture(animated.animation, animated.frame)
		ghost.centered = animated.centered
		ghost.offset = animated.offset
		ghost.flip_h = animated.flip_h
		ghost.flip_v = animated.flip_v
	else:
		var still := source as Sprite2D
		ghost.texture = still.texture
		ghost.centered = still.centered
		ghost.offset = still.offset
		ghost.flip_h = still.flip_h
		ghost.flip_v = still.flip_v
		ghost.region_enabled = still.region_enabled
		ghost.region_rect = still.region_rect
		ghost.hframes = still.hframes
		ghost.vframes = still.vframes
		ghost.frame = still.frame
	if ghost.texture == null:
		return null
	ghost.global_transform = source.global_transform
	ghost.modulate = TINT
	ghost.texture_filter = source.texture_filter
	return ghost
