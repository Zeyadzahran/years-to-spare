class_name TimePowers
extends Node
## Turns the ability inputs into a TimeService mode and bills the player in
## years for the privilege.
##
## A power is cast, not held. One press buys up to five seconds of Stop Time
## at a fixed price in years. A second press ends it early; otherwise it expires.
## The cost is paid once on activation, and cooldown starts when the power ends.
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
## Rewind is the same shape: one press, a fixed price, and TimeService.REWIND_SPAN
## seconds of the world - the boy included - run back at REWIND_SPEED. Its
## window is how long that takes, not how far it reaches. The flourish runs on
## forward time, so the span is measured from the moment it lands, a little
## before the press itself. Slow is still a placeholder.

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
const REWIND_COST := 4.0

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
		Power.new(GameState.ABILITY_REWIND, &"time_rewind", TimeService.Mode.REWINDING,
			TimeService.REWIND_SPAN / TimeService.REWIND_SPEED, REWIND_COST, 6.0),
		Power.new(GameState.ABILITY_SLOW, &"time_slow", TimeService.Mode.SLOWED, 6.0, 4.0, 4.0),
	]


func _process(delta: float) -> void:
	for id in _cooldowns.keys():
		_cooldowns[id] = maxf(_cooldowns[id] - delta, 0.0)

	# A fresh press releases Stop Time, including during its wind-up. Holding
	# the button never toggles it repeatedly or spends another activation cost.
	if is_casting(GameState.ABILITY_STOP) and Input.is_action_just_pressed(&"time_stop"):
		cancel()
		return

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
## Forgives a power's cooldown outright. A lesson uses it so the press it is
## teaching cannot be refused for the practice that came just before.
func clear_cooldown(id: StringName) -> void:
	_cooldowns.erase(id)


func cooldown_left(id: StringName) -> float:
	return _cooldowns.get(id, 0.0)


func is_ready(id: StringName) -> bool:
	return active == null and _pending == null \
		and is_zero_approx(cooldown_left(id)) and GameState.has_ability(id)


## Shared by the death screen and keyboard input during the collapse animation.
func death_rewind_block_reason() -> String:
	if age == null or age.age >= age.death_age:
		return "Your time has run out."
	if not GameState.has_ability(GameState.ABILITY_REWIND):
		return "Rewind is not unlocked yet."
	if cooldown_left(GameState.ABILITY_REWIND) > 0.0:
		return "Rewind is cooling down."
	if age.age + REWIND_COST >= age.death_age:
		return "Not enough years left to rewind."
	if not is_ready(GameState.ABILITY_REWIND):
		return "Rewind is unavailable."
	if not TimeService.can_restore_player(get_parent(), WIND_UP):
		return "No safe moment to rewind to."
	return ""


func rewind_after_death() -> bool:
	if not death_rewind_block_reason().is_empty():
		return false
	for power in _powers:
		if power.id == GameState.ABILITY_REWIND:
			_try_cast(power)
			return _pending == power
	return false


## Paid for and playing out his flourish, but the world is still running.
func is_winding_up() -> bool:
	return _pending != null


## Whether `id` is the power under way, winding up or already landed. Dying
## asks this: a rewind pressed on the way into the spikes has to outlive the
## death that follows, since undoing it is the whole reason he pressed.
func is_casting(id: StringName) -> bool:
	var casting := active if active != null else _pending
	return casting != null and casting.id == id


## Casts `id` on the boy's behalf - the clock catching him on the way into
## the void. Refuses while another power is running; reports whether the
## requested power is now under way, winding up or already landed.
func try_cast(id: StringName) -> bool:
	if active != null or _pending != null:
		return false
	for power in _powers:
		if power.id == id:
			_try_cast(power)
			return is_casting(id)
	return false


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
	var player := get_parent() as Player
	if player != null and player.is_down():
		if power.id != GameState.ABILITY_REWIND or not death_rewind_block_reason().is_empty():
			return
	if not GameState.has_ability(power.id) or not is_zero_approx(cooldown_left(power.id)):
		return
	if age == null:
		return
	# A press he cannot pay for costs him what he has left and nothing
	# happens: the years are the point of the game, and a man who spends the
	# last of them on a trick he had no time for has spent his life. The clock
	# stops at sixty and takes him with it.
	if power.cost > age.death_age - age.age:
		age.spend(power.cost)
		return
	# Charged on commitment rather than on arrival: he has decided, and the
	# half second of flourish is paid for even if he cancels before it lands.
	_pending = power
	_wind_left = WIND_UP
	age.spend(power.cost)
	EventBus.ability_started.emit(power.id)
