class_name PickupPlacer
extends Node
## Decides which of a level's candidate pickups exist this run. A level is
## authored with more figs and hearts than it will show; this picks from them
## once per run, before the first frame, and the rest are gone as if they had
## never been placed. The layout itself is never generated - only what lies
## on it.
##
## The rules, in the order they are applied:
##
##   - the run's seed decides, so the same seed lays a level out the same way
##     and a retry finds every fig and heart where it was (GameState keeps
##     the answers, the seed only makes them);
##   - figs: every stretch between two checkpoints that has a candidate gets
##     at least one, so no checkpoint is followed by a dry run to the next;
##     then random ones fill the budget. Never two within `fig_spacing` where
##     there is a choice;
##   - hearts: a gamble, not a guarantee - random ones up to the budget, at
##     most one per stretch and never two within `heart_spacing`;
##   - pity: a death that sends him back to a checkpoint adds one fig, the
##     nearest unchosen candidate ahead of the marker. It stays for the rest
##     of the run, and the next death there adds the next one.
##
## A pickup marked `fixed` is not a candidate: it is where its author put it,
## on every run. Sits directly under the Level root, which calls place() from
## its own load.

## How many loose figs the level shows on a run.
@export var fig_count := 8
## How many hearts - in boxes or on the ground - the level shows on a run.
@export var heart_count := 3
## Two chosen figs are never closer than this along the level.
@export var fig_spacing := 700.0
## Two chosen hearts are never closer than this along the level.
@export var heart_spacing := 1500.0

## The figs this load left out, tag -> where they would have been. They are
## gone from the tree, so this is what pity picks from.
var _absent_figs: Dictionary[String, float] = {}


## Every candidate that is not lying there on this load, by tag. Read by
## tests; nothing in the game needs it.
var removed: Array[String] = []


func place(level: Node, level_id: StringName) -> void:
	removed.clear()
	_absent_figs.clear()
	var figs := _candidates(level, &"fig_pickup")
	var hearts := _candidates(level, &"heart_pickup")
	var bounds := _stretch_bounds(level)
	if not GameState.has_placement(level_id):
		if GameState.run_seed == 0:
			GameState.run_seed = randi()
		var rng := RandomNumberGenerator.new()
		rng.seed = GameState.run_seed ^ hash(level_id)
		_decide(level_id, figs, bounds, rng, fig_count, fig_spacing, true)
		_decide(level_id, hearts, bounds, rng, heart_count, heart_spacing, false)
	for pickup in figs + hearts:
		var tag: String = pickup.get_meta(&"placement_tag")
		if not GameState.is_pickup_placed(level_id, tag):
			removed.append(tag)
			if figs.has(pickup):
				_absent_figs[tag] = pickup.global_position.x
			pickup.queue_free()


## Candidates of one kind, left to right, each tagged with its path inside
## the level - the same name a retry keys its answers on.
func _candidates(level: Node, group: StringName) -> Array[Node2D]:
	var found: Array[Node2D] = []
	for node in level.get_tree().get_nodes_in_group(group):
		if not (node is Node2D) or not level.is_ancestor_of(node):
			continue
		if node.get(&"fixed") == true:
			continue
		node.set_meta(&"placement_tag", String(level.get_path_to(node)))
		found.append(node)
	found.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return a.global_position.x < b.global_position.x)
	return found


## Where the stretches begin: every checkpoint's x, sorted. A candidate is in
## stretch i when it lies between bound i and bound i + 1 (or past the last).
func _stretch_bounds(level: Node) -> Array[float]:
	var bounds: Array[float] = [-INF]
	for node in level.find_children("*", "Checkpoint", true, false):
		bounds.append((node as Node2D).global_position.x)
	bounds.sort()
	return bounds


func _stretch_of(x: float, bounds: Array[float]) -> int:
	var index := 0
	for i in bounds.size():
		if x >= bounds[i]:
			index = i
	return index


func _decide(level_id: StringName, candidates: Array[Node2D], bounds: Array[float],
		rng: RandomNumberGenerator, count: int, spacing: float, cover_every_stretch: bool) -> void:
	var chosen: Array[Node2D] = []
	var by_stretch: Dictionary[int, Array] = {}
	for pickup in candidates:
		var stretch := _stretch_of(pickup.global_position.x, bounds)
		if not by_stretch.has(stretch):
			by_stretch[stretch] = []
		by_stretch[stretch].append(pickup)
	if cover_every_stretch:
		for stretch in by_stretch:
			var pool: Array = by_stretch[stretch]
			_shuffle(pool, rng)
			# The first that keeps its distance; the stretch gets one regardless.
			var pick: Node2D = pool[0]
			for candidate in pool:
				if not _too_close(candidate, chosen, spacing):
					pick = candidate
					break
			chosen.append(pick)
	var rest := candidates.duplicate()
	for pickup in chosen:
		rest.erase(pickup)
	_shuffle(rest, rng)
	for pickup in rest:
		if chosen.size() >= count:
			break
		if _too_close(pickup, chosen, spacing):
			continue
		if not cover_every_stretch \
				and _stretch_taken(_stretch_of(pickup.global_position.x, bounds), chosen, bounds):
			continue
		chosen.append(pickup)
	for pickup in candidates:
		GameState.place_pickup(level_id, pickup.get_meta(&"placement_tag"), chosen.has(pickup))


func _too_close(pickup: Node2D, chosen: Array[Node2D], spacing: float) -> bool:
	for other in chosen:
		if absf(other.global_position.x - pickup.global_position.x) < spacing:
			return true
	return false


func _stretch_taken(stretch: int, chosen: Array[Node2D], bounds: Array[float]) -> bool:
	for other in chosen:
		if _stretch_of(other.global_position.x, bounds) == stretch:
			return true
	return false


## Fisher-Yates on the run's own generator; Array.shuffle() would draw from
## the global one and the layout would stop following the seed.
func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = items[i]
		items[i] = items[j]
		items[j] = swap


## One more fig for a death he is about to retry from the marker: the nearest
## candidate ahead of it that was not chosen. Called by the level on the way
## out, so the fig is in the run's answers before the reload lays the level
## out again - and stays there. Returns the tag it added, or "" when every
## candidate ahead of the marker is already lying there.
func take_pity(level_id: StringName) -> String:
	if not GameState.has_checkpoint(level_id):
		return ""
	var marker_x := GameState.checkpoint_position.x
	var nearest := ""
	for tag in _absent_figs:
		var x: float = _absent_figs[tag]
		if x < marker_x or GameState.is_pickup_placed(level_id, tag):
			continue
		if nearest == "" or x < _absent_figs[nearest]:
			nearest = tag
	if nearest != "":
		GameState.place_pickup(level_id, nearest, true)
	return nearest
