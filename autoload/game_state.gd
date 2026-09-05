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
]

var level_index := 0
var unlocked: Array[StringName] = []

## What a death carries forward. Deliberately not cleared by `start_new_run()`:
## that runs on every level load, including the reload a death triggers, which
## is exactly when this is needed. What clears it is `clear_run_progress()` -
## PLAY on the main menu, reaching the next phase, and dying of old age.
var checkpoint_id: StringName = &""
var checkpoint_level: StringName = &""
var checkpoint_position := Vector2.ZERO

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

func start_new_run() -> void:
	level_index = 0
	unlocked.clear()
	_grant_for_current_level()


## Called by a Checkpoint the first time the boy passes it.
func set_checkpoint(id: StringName, position: Vector2, age: float) -> void:
	checkpoint_id = id
	checkpoint_level = current_level()["id"]
	checkpoint_position = position
	run_age = age


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


## Throws away everything a retry would have carried: the marker, the years
## already spent, and the bodies. This is what "start over" means.
func clear_run_progress() -> void:
	checkpoint_id = &""
	checkpoint_level = &""
	checkpoint_position = Vector2.ZERO
	run_age = -1.0
	cleared_enemies.clear()


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


func _grant_for_current_level() -> void:
	var id: StringName = current_level()["grants"]
	if not unlocked.has(id):
		unlocked.append(id)
		EventBus.ability_unlocked.emit(id)
