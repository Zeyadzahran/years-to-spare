extends Node
## Pickup placement in both levels: the figs and hearts a run shows are
## chosen from the authored candidates by seed, under the placer's rules,
## and a retry finds them where they were. Run with --headless --fixed-fps 60.

const LEVELS := {
	&"phase_1": "res://src/levels/level_01/level_01.tscn",
	&"phase_2": "res://src/levels/level_02/level_02.tscn",
}
## Figs sit a little above the floor they are drawn on; a probe dropped from
## one lands within this.
const FLOOR_REACH := 80.0

## Keeps a death from reloading the test scene itself.
class QuietLevel extends Level:
	func reload() -> void:
		TimeService.reset()

var failures := 0
var level: Level
var placer: PickupPlacer
## Every candidate of each kind on the last load: {tag, x, y, present}.
var figs: Array[Dictionary] = []
var hearts: Array[Dictionary] = []
var checkpoints: Array[float] = []


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


## Loads a level; with a seed, as a fresh run on that seed, otherwise as a
## retry of whatever run is in progress.
func load_level(level_id: StringName, seed: int = -1) -> void:
	TimeService.reset()
	if is_instance_valid(level):
		level.queue_free()
		await frames(2)
	if seed >= 0:
		GameState.clear_run_progress()
		GameState.run_seed = seed
	level = load(LEVELS[level_id]).instantiate()
	level.set_script(QuietLevel)
	# A fresh script instance starts from the defaults, not the scene's values.
	level.level_id = level_id
	level.debug_spawn_path = NodePath()
	add_child(level)
	get_tree().current_scene = self
	placer = level.get_node("PickupPlacer")
	# The placer has run and the losers are queued, not gone: this is the one
	# moment every candidate can still be looked at.
	figs = _survey(&"fig_pickup")
	hearts = _survey(&"heart_pickup")
	checkpoints.clear()
	for node in level.find_children("*", "Checkpoint", true, false):
		checkpoints.append((node as Node2D).global_position.x)
	checkpoints.sort()
	for node in level.find_children("*", "Enemy", true, false):
		node.process_mode = Node.PROCESS_MODE_DISABLED
	await frames(2)


func _survey(group: StringName) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group(group):
		if not level.is_ancestor_of(node) or node.get(&"fixed") == true:
			continue
		found.append({
			"tag": String(level.get_path_to(node)),
			"x": node.global_position.x,
			"y": node.global_position.y,
			"present": not node.is_queued_for_deletion(),
		})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.x < b.x)
	return found


func present(candidates: Array[Dictionary]) -> Array[Dictionary]:
	return candidates.filter(func(c: Dictionary) -> bool: return c.present)


func tags(candidates: Array[Dictionary]) -> Array:
	var out := []
	for c in present(candidates):
		out.append(c.tag)
	return out


func stretch_of(x: float) -> int:
	var index := 0
	for i in checkpoints.size():
		if x >= checkpoints[i]:
			index = i + 1
	return index


## The rules, on whatever the last load chose.
func rules(level_id: StringName) -> void:
	var shown := present(figs)
	check(figs.size() > placer.fig_count, "%s has no more fig candidates (%d) than its budget %d" % [level_id, figs.size(), placer.fig_count])
	check(shown.size() == placer.fig_count, "%s shows %d figs, budget %d" % [level_id, shown.size(), placer.fig_count])
	var covered := {}
	for fig in shown:
		covered[stretch_of(fig.x)] = true
	for fig in figs:
		check(covered.has(stretch_of(fig.x)), "%s: stretch %d has candidates but no fig (%s)" % [level_id, stretch_of(fig.x), fig.tag])
	for i in shown.size():
		for j in range(i + 1, shown.size()):
			var a: Dictionary = shown[i]
			var b: Dictionary = shown[j]
			if absf(a.x - b.x) < placer.fig_spacing and stretch_of(a.x) == stretch_of(b.x):
				check(false, "%s: figs %s and %s crowd one stretch" % [level_id, a.tag, b.tag])
	var shown_hearts := present(hearts)
	check(hearts.size() > placer.heart_count, "%s has no more heart candidates (%d) than its budget %d" % [level_id, hearts.size(), placer.heart_count])
	check(shown_hearts.size() == placer.heart_count, "%s shows %d hearts, budget %d" % [level_id, shown_hearts.size(), placer.heart_count])
	var heart_stretches := {}
	for i in shown_hearts.size():
		var a: Dictionary = shown_hearts[i]
		check(not heart_stretches.has(stretch_of(a.x)), "%s: two hearts in stretch %d" % [level_id, stretch_of(a.x)])
		heart_stretches[stretch_of(a.x)] = true
		for j in range(i + 1, shown_hearts.size()):
			check(absf(a.x - shown_hearts[j].x) >= placer.heart_spacing, "%s: hearts %s and %s too close" % [level_id, a.tag, shown_hearts[j].tag])
	for tag in figs.map(func(c: Dictionary) -> String: return c.tag) + hearts.map(func(c: Dictionary) -> String: return c.tag):
		check(GameState.pickup_rolls.has("%s|%s" % [level_id, tag]), "%s: %s was never decided" % [level_id, tag])


## Same seed, same level; a retry keeps it; another seed lays it out anew.
func seeds(level_id: StringName) -> void:
	await load_level(level_id, 7)
	var first_figs := tags(figs)
	var first_hearts := tags(hearts)
	await load_level(level_id, 7)
	check(tags(figs) == first_figs and tags(hearts) == first_hearts, "%s: the same seed laid the level out differently" % level_id)
	await load_level(level_id)
	check(tags(figs) == first_figs and tags(hearts) == first_hearts, "%s: a retry moved the pickups" % level_id)
	var differs := false
	for seed in range(8, 14):
		await load_level(level_id, seed)
		rules(level_id)
		if tags(figs) != first_figs or tags(hearts) != first_hearts:
			differs = true
	check(differs, "%s: six other seeds all laid the level out the same way" % level_id)
	print("PLACEMENT %s: %d/%d figs and %d/%d hearts per run, seeded, kept on retry" % [level_id, placer.fig_count, figs.size(), placer.heart_count, hearts.size()])


## A death sent back to a marker adds the nearest left-out fig ahead of it,
## and the next death the next one; hearts are never handed out this way.
func pity(level_id: StringName, marker: StringName, at: Vector2) -> void:
	await load_level(level_id, 7)
	var before := tags(figs)
	var hearts_before := tags(hearts)
	var expected := []
	for fig in figs:
		if not fig.present and fig.x >= at.x:
			expected.append(fig.tag)
	check(expected.size() >= 2, "%s: not enough left-out figs past %s to test pity" % [level_id, marker])
	GameState.set_checkpoint(marker, at, level.get_node("Entities/Player").age.age)
	level._on_player_died(false)
	await load_level(level_id)
	var after := tags(figs)
	check(after.size() == before.size() + 1 and after.has(expected[0]), "%s: one death did not add the nearest fig past the marker" % level_id)
	check(tags(hearts) == hearts_before, "%s: pity handed out a heart" % level_id)
	level._on_player_died(false)
	await load_level(level_id)
	after = tags(figs)
	check(after.size() == before.size() + 2 and after.has(expected[0]) and after.has(expected[1]), "%s: a second death did not add the next fig" % level_id)
	# Nothing behind the marker is ever added.
	for fig in figs:
		if fig.present and not before.has(fig.tag):
			check(fig.x >= at.x, "%s: pity added a fig behind the marker: %s" % [level_id, fig.tag])
	print("PLACEMENT %s: each death at %s adds the next fig ahead of it" % [level_id, marker])


## Hand-placed rewards are there on every seed.
func fixed_figs() -> void:
	for seed in [7, 8, 9]:
		await load_level(&"phase_1", seed)
		for path in ["World/SalvageYard/Pickups/HighLedgeFig", "World/SalvageYard/Pickups/ExitFig"]:
			var fig := level.get_node_or_null(path)
			check(fig != null and not fig.is_queued_for_deletion(), "Seed %d removed the fixed fig %s" % [seed, path])
	print("PLACEMENT fixed figs stay on every seed")


## Every fig candidate hangs just over a floor: a body dropped from it lands
## within reach, so no run can lay a fig in a pit or in the air.
func floors(level_id: StringName) -> void:
	await load_level(level_id, 7)
	var probes: Array[CharacterBody2D] = []
	for fig in figs:
		var probe := CharacterBody2D.new()
		probe.collision_layer = 0
		probe.collision_mask = 1
		var shape := CollisionShape2D.new()
		shape.shape = RectangleShape2D.new()
		shape.shape.size = Vector2(16, 16)
		probe.add_child(shape)
		probe.global_position = Vector2(fig.x, fig.y)
		add_child(probe)
		probes.append(probe)
	for i in 90:
		await get_tree().physics_frame
		for probe in probes:
			probe.velocity.y += 980.0 / 60.0
			probe.move_and_slide()
	for i in probes.size():
		var fell: float = probes[i].global_position.y - figs[i].y
		check(probes[i].is_on_floor() and fell >= 0.0 and fell <= FLOOR_REACH, "%s: fig %s has no floor under it (fell %.0f)" % [level_id, figs[i].tag, fell])
		probes[i].queue_free()
	print("PLACEMENT %s: all %d fig candidates sit on floors" % [level_id, figs.size()])


func _ready() -> void:
	for level_id in LEVELS:
		await seeds(level_id)
		await floors(level_id)
	await pity(&"phase_2", &"L2Rooftops", Vector2(3206, 521))
	await pity(&"phase_1", &"Checkpoint3", Vector2(4300, 600))
	await fixed_figs()
	print("PICKUP_PLACEMENT_VERIFIED failures=%d" % failures)
	GameState.clear_run_progress()
	TimeService.reset()
	level.queue_free()
	await frames(2)
	get_tree().quit(1 if failures else 0)
