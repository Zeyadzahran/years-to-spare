extends Node
## Run-level progress: which phase we are on and which time powers are unlocked.
## Levels read this on load; nothing else needs to know the order of the game.

const ABILITY_STOP := &"stop"
const ABILITY_REWIND := &"rewind"
const ABILITY_SLOW := &"slow"

## Fill in as phases are built.
const LEVELS: Array[Dictionary] = [
	{
		"id": &"phase_1",
		"scene": "res://src/levels/level_01/level_01.tscn",
		"grants": ABILITY_STOP,
	},
	{
		"id": &"phase_2",
		"scene": "res://src/levels/level_02/level_02.tscn",
		"grants": ABILITY_REWIND,
	},
]

## Lives, not health: three tries at a checkpoint before a mistake costs the
## whole level rather than just the ground since the last marker.
const MAX_HEARTS := 3
## Hearts picked up along the way stack past the starting three, up to here.
const HEART_CAP := 9

var level_index := 0
var unlocked: Array[StringName] = []

## What a death carries forward. Deliberately not cleared by `start_new_run()`:
## that runs on every level load, including the reload a death triggers, which
## is exactly when this is needed. What clears it is `clear_run_progress()` -
## PLAY on the main menu, reaching the next phase, and dying of old age.
var checkpoint_id: StringName = &""
var checkpoint_level: StringName = &""
var checkpoint_position := Vector2.ZERO
## Whether the checkpoint above was reached with Level 02's Day/Night
## transition already active. Unused by any level without that concept - a
## checkpoint there always passes false and nothing ever reads it as true.
var checkpoint_night := false

## Live, not saved: whatever a level's own day/night trigger currently has
## in effect, so a Checkpoint (shared across levels, no notion of day/night
## of its own) can read the moment of passing rather than needing a level
## to hand it down directly. What actually survives a death is the snapshot
## above, taken from this the instant a checkpoint records itself - not this.
var night_active := false

## Same shape as the checkpoint above: a death does not touch this, only
## `clear_run_progress()` does - so three tries at a marker have to run out
## before this resets, not one reload of it.
var hearts := MAX_HEARTS

## The age the boy carries into his next attempt. Dying is not a fountain of
## youth: the years he spent are spent, and only the ground he covered is lost.
## Negative until he has died at least once, which means "leave him as the scene
## starts him".
var run_age := -1.0

## Bodies he has already left behind, keyed "<level id>|<path inside the level>".
## A retry is a retry, not a re-run: a Guard downed before the last checkpoint
## stays down, so a hard stretch cannot be farmed for the years its troops pay
## out - and so clearing a room actually means something.
var cleared_enemies: Dictionary[String, bool] = {}

## Hearts he has already picked up, keyed the same way. A retry puts him back
## at the marker, not back in time: a heart taken before it stays taken, so a
## stretch with a heart on it cannot be died through for a free life each time.
var collected_hearts: Dictionary[String, bool] = {}

## Which boxes turned out to hold a heart this run, keyed the same way. Rolled
## the first time a level asks and kept until the run is over, so a retry
## finds the same boxes full and the same ones empty - and the next run
## finds a different set.
var heart_rolls: Dictionary[String, bool] = {}

func start_new_run(level_id: StringName = &"phase_1") -> void:
	level_index = 0
	for index in LEVELS.size():
		if LEVELS[index]["id"] == level_id:
			level_index = index
			break
	# A directly opened phase must not inherit another phase's retry state.
	if checkpoint_level != &"" and checkpoint_level != level_id:
		clear_run_progress()
	unlocked.clear()
	_grant_for_current_level()


## Called by a Checkpoint the first time the boy passes it.
func set_checkpoint(id: StringName, position: Vector2, age: float, night: bool = false) -> void:
	checkpoint_id = id
	checkpoint_level = current_level()["id"]
	checkpoint_position = position
	run_age = age
	checkpoint_night = night


## Whether `id` names the checkpoint currently recorded. Checked by the marker
## itself, so it asks about the level it is standing in.
func is_active_checkpoint(id: StringName) -> bool:
	return has_checkpoint(current_level()["id"]) and checkpoint_id == id


## True once a checkpoint in this level has been reached; until then a death
## restarts the level the way it always has.
func has_checkpoint(level_id: StringName) -> bool:
	return checkpoint_id != &"" and checkpoint_level == level_id


## Marks a unit as downed for the rest of the run.
func clear_enemy(level_id: StringName, path: String) -> void:
	cleared_enemies["%s|%s" % [level_id, path]] = true


func is_enemy_cleared(level_id: StringName, path: String) -> bool:
	return cleared_enemies.has("%s|%s" % [level_id, path])


## A rewind has stood a downed unit back up. Unmarked again, or the next reload
## would remove a unit that is visibly alive.
func revive_enemy(level_id: StringName, path: String) -> void:
	cleared_enemies.erase("%s|%s" % [level_id, path])


## Marks a heart as picked up for the rest of the run.
func collect_heart(level_id: StringName, path: String) -> void:
	collected_hearts["%s|%s" % [level_id, path]] = true


func is_heart_collected(level_id: StringName, path: String) -> bool:
	return collected_hearts.has("%s|%s" % [level_id, path])


## A rewind has put a heart back on the ground. Unmarked again, or the next
## reload would remove a heart that is visibly there.
func restore_heart(level_id: StringName, path: String) -> void:
	collected_hearts.erase("%s|%s" % [level_id, path])


## Whether a heart is in its box this run: rolled at `chance` the first time
## it is asked about, the same answer every time after.
func roll_heart(level_id: StringName, path: String, chance: float) -> bool:
	var key := "%s|%s" % [level_id, path]
	if not heart_rolls.has(key):
		heart_rolls[key] = randf() < chance
	return heart_rolls[key]


## Throws away everything a retry would have carried: the marker, the years
## already spent, the bodies, and now the hearts - this is what "start over"
## means, and running out of hearts is one more way to mean it.
func clear_run_progress() -> void:
	checkpoint_id = &""
	checkpoint_level = &""
	checkpoint_position = Vector2.ZERO
	checkpoint_night = false
	night_active = false
	run_age = -1.0
	cleared_enemies.clear()
	collected_hearts.clear()
	heart_rolls.clear()
	hearts = MAX_HEARTS
	EventBus.player_hearts_changed.emit(hearts, HEART_CAP)


## Called on every death that is not old age. The return value is what
## Level._on_player_died reads to decide a checkpoint respawn still covers it
## or whether this was the third and the level starts over instead.
func lose_heart() -> int:
	hearts = maxi(hearts - 1, 0)
	EventBus.player_hearts_changed.emit(hearts, HEART_CAP)
	return hearts


## A heart picked up off the ground. One more try, up to the cap; the return
## value is what the pickup reads to know whether it was actually taken.
func gain_heart() -> int:
	hearts = mini(hearts + 1, HEART_CAP)
	EventBus.player_hearts_changed.emit(hearts, HEART_CAP)
	return hearts


func current_level() -> Dictionary:
	return LEVELS[clampi(level_index, 0, LEVELS.size() - 1)]


func has_ability(id: StringName) -> bool:
	return unlocked.has(id)


func advance() -> bool:
	if level_index >= LEVELS.size() - 1:
		return false
	level_index += 1
	clear_run_progress()
	_grant_for_current_level()
	return true


## Every phase up to this one: a power once earned stays his, so phase 2 has
## Stop as well as the Rewind it introduces.
func _grant_for_current_level() -> void:
	for index in range(clampi(level_index, 0, LEVELS.size() - 1) + 1):
		var id: StringName = LEVELS[index]["grants"]
		if not unlocked.has(id):
			unlocked.append(id)
			EventBus.ability_unlocked.emit(id)
