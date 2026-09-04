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
## A press does not stop the world on the frame it lands. The boy plays his
## flourish first and the world stops on its last frame, because the alternative
## reads backwards: the power has already taken hold while he is still visibly
## reaching for it. It is half a second, and it is the difference between the
## animation causing the freeze and merely accompanying it.
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

## Seconds between the press and the world actually stopping - the boy's
## flourish. PlayerAnimator stretches whichever of the three power clips he is
## wearing to exactly this long, so the freeze always lands on its last frame
## whatever body he is in.
const WIND_UP := 0.5

@export var age: AgeComponent

## The power currently running, and how much of its window is left.
var active: Power = null
var time_left := 0.0

var _powers: Array[Power] = []
var _cooldowns: Dictionary[StringName, float] = {}
## Cast and paid for, still winding up. The world is untouched until it lands.
var _pending: Power = null
var _wind_left := 0.0

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

	if _pending != null:
		_wind_left = maxf(_wind_left - delta, 0.0)
		if is_zero_approx(_wind_left):
			_engage()
		return

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
	return active == null and _pending == null \
		and is_zero_approx(cooldown_left(id)) and GameState.has_ability(id)


## Paid for and playing out his flourish, but the world is still running.
func is_winding_up() -> bool:
	return _pending != null


## Ends a power, whether it had taken hold or was still winding up. The cooldown
## runs either way: the years are spent the moment he commits.
func cancel() -> void:
	var stopped := active if active != null else _pending
	if stopped == null:
		return
	active = null
	_pending = null
	time_left = 0.0
	_wind_left = 0.0
	_cooldowns[stopped.id] = stopped.cooldown
	TimeService.mode = TimeService.Mode.NORMAL
	EventBus.ability_stopped.emit(stopped.id)


## The flourish has finished. Now the world stops, and the window starts.
func _engage() -> void:
	active = _pending
	_pending = null
	time_left = active.duration
	TimeService.mode = active.mode
	EventBus.ability_engaged.emit(active.id, active.duration)


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
	# Charged on commitment rather than on arrival: he has decided, and the
	# half second of flourish is not a window to change his mind in.
	_pending = power
	_wind_left = WIND_UP
	age.spend(power.cost)
	EventBus.ability_started.emit(power.id)
