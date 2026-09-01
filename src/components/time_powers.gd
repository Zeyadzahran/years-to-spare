class_name TimePowers
extends Node
## Turns the ability inputs into a TimeService mode and bills the player in
## years for every second a power is held.
##
## Costs and the rewind implementation are placeholders until the phases exist.

class Power:
	var id: StringName
	var action: StringName
	var mode: int
	var cost_per_second: float

	func _init(p_id: StringName, p_action: StringName, p_mode: int, p_cost: float) -> void:
		id = p_id
		action = p_action
		mode = p_mode
		cost_per_second = p_cost

@export var age: AgeComponent

var active_id: StringName = &""

var _powers: Array[Power] = []

func _ready() -> void:
	_powers = [
		Power.new(GameState.ABILITY_STOP, &"time_stop", TimeService.Mode.STOPPED, 3.0),
		Power.new(GameState.ABILITY_REWIND, &"time_rewind", TimeService.Mode.REWINDING, 2.0),
		Power.new(GameState.ABILITY_SLOW, &"time_slow", TimeService.Mode.SLOWED, 1.2),
	]


func _process(delta: float) -> void:
	var wanted := _wanted_power()
	if wanted != null and wanted.id != active_id:
		_start(wanted)
	elif wanted == null and not active_id.is_empty():
		cancel()

	if not active_id.is_empty() and age != null:
		age.spend(_find(active_id).cost_per_second * delta)


func cancel() -> void:
	if active_id.is_empty():
		return
	var stopped := active_id
	active_id = &""
	TimeService.mode = TimeService.Mode.NORMAL
	EventBus.ability_stopped.emit(stopped)


func _wanted_power() -> Power:
	for power in _powers:
		if Input.is_action_pressed(power.action) and GameState.has_ability(power.id):
			return power
	return null


func _start(power: Power) -> void:
	active_id = power.id
	TimeService.mode = power.mode
	EventBus.ability_started.emit(power.id)


func _find(id: StringName) -> Power:
	for power in _powers:
		if power.id == id:
			return power
	return null
