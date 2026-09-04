class_name TimePowers
extends Node
## Turns the ability inputs into a TimeService mode and bills the player in
## years for the privilege.
##
## A power is *cast*, not held: one press buys a fixed window - five seconds of
## a stopped world - at a fixed price in years, and it runs itself out. Holding
## a key while a counter climbed made the cost invisible until it had already
## been paid, and gave the moment no shape: no start, no end, nothing to react
## to. A press with a known length and a known price is a decision.
##
## The cast is timed on the real clock, not the world one: the world's clock is
## the thing that has been stopped, so counting on it would never tick down.
##
## Rewind is still a placeholder; only Stop is granted in phase 1.

class Power:
	var id: StringName
	var action: StringName
	var mode: int
	## Seconds the world spends in that mode, per press.
	var duration: float
	## Years the press costs, paid in full the moment it is cast.
	var cost: float
	## Seconds before it can be cast again, counted from the end of the cast.
	var cooldown: float

	func _init(p_id: StringName, p_action: StringName, p_mode: int,
			p_duration: float, p_cost: float, p_cooldown: float) -> void:
		id = p_id
		action = p_action
		mode = p_mode
		duration = p_duration
		cost = p_cost
		cooldown = p_cooldown

@export var age: AgeComponent

## The power currently running, and how much of its window is left.
var active: Power = null
var time_left := 0.0

var _powers: Array[Power] = []
var _cooldowns: Dictionary[StringName, float] = {}

func _ready() -> void:
	# Numbers to be tuned by playing, not derived. The shape they are aiming
	# for: a stop is worth three of Cad Corp's troops, so a room cleared pays
	# for the stop that cleared it and a little over, and a boy who spends
	# without killing walks himself into his sixties in about fifteen presses.
	_powers = [
		Power.new(GameState.ABILITY_STOP, &"time_stop", TimeService.Mode.STOPPED, 5.0, 3.0, 3.0),
		Power.new(GameState.ABILITY_REWIND, &"time_rewind", TimeService.Mode.REWINDING, 2.0, 4.0, 6.0),
		Power.new(GameState.ABILITY_SLOW, &"time_slow", TimeService.Mode.SLOWED, 6.0, 4.0, 4.0),
	]


func _process(delta: float) -> void:
	for id in _cooldowns.keys():
		_cooldowns[id] = maxf(_cooldowns[id] - delta, 0.0)

	if active != null:
		time_left = maxf(time_left - delta, 0.0)
		if is_zero_approx(time_left):
			cancel()
		return

	for power in _powers:
		if Input.is_action_just_pressed(power.action):
			_try_cast(power)
			return


## Seconds before `id` can be cast again; 0 when it is ready.
func cooldown_left(id: StringName) -> float:
	return _cooldowns.get(id, 0.0)


func is_ready(id: StringName) -> bool:
	return active == null and is_zero_approx(cooldown_left(id)) and GameState.has_ability(id)


func cancel() -> void:
	if active == null:
		return
	var stopped := active
	active = null
	time_left = 0.0
	_cooldowns[stopped.id] = stopped.cooldown
	TimeService.mode = TimeService.Mode.NORMAL
	EventBus.ability_stopped.emit(stopped.id)


func _try_cast(power: Power) -> void:
	if not GameState.has_ability(power.id) or not is_zero_approx(cooldown_left(power.id)):
		return
	if age == null:
		return
	# Refused rather than allowed to kill him. Charging the last few years and
	# ending the run inside his own power would read as the game cheating; the
	# HUD says what he was short instead.
	var affordable := age.death_age - age.age
	if power.cost > affordable:
		EventBus.ability_refused.emit(power.id, power.cost - affordable)
		return
	active = power
	time_left = power.duration
	age.spend(power.cost)
	TimeService.mode = power.mode
	EventBus.ability_started.emit(power.id)
