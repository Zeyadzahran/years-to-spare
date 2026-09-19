extends Node
## Exercise actual press/release input, automatic expiry, costs and cooldowns.

var failures := 0
var age: AgeComponent
var powers: TimePowers


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func frames(count: int) -> void:
	for frame in count:
		await get_tree().process_frame


func press() -> void:
	Input.action_press(&"time_stop")
	await frames(2)


func release() -> void:
	Input.action_release(&"time_stop")
	await frames(2)


func _ready() -> void:
	GameState.start_new_run()
	TimeService.reset()
	age = AgeComponent.new()
	add_child(age)
	powers = TimePowers.new()
	powers.age = age
	add_child(powers)
	var initial_age := age.age
	await press()
	check(powers.is_winding_up(), "First press did not start the cast")
	await frames(50)
	check(TimeService.mode == TimeService.Mode.STOPPED, "Holding the first press canceled Stop Time")
	check(is_equal_approx(age.age, initial_age + 3.0), "Activation must cost three years once")
	await release()
	check(TimeService.mode == TimeService.Mode.STOPPED, "Releasing the button canceled Stop Time")
	await press()
	check(TimeService.mode == TimeService.Mode.NORMAL and powers.active == null,
		"Second press did not resume time immediately")
	check(is_equal_approx(age.age, initial_age + 3.0), "Ending early charged extra years")
	check(powers.cooldown_left(GameState.ABILITY_STOP) > 2.8, "Ending early skipped the cooldown")
	await release()
	await press()
	check(not powers.is_casting(GameState.ABILITY_STOP), "Cooldown allowed another cast")
	await frames(200)
	check(not powers.is_casting(GameState.ABILITY_STOP), "Holding the button recast after cooldown")
	await release()
	await press()
	await release()
	await press()
	check(not powers.is_casting(GameState.ABILITY_STOP) and TimeService.mode == TimeService.Mode.NORMAL,
		"Second press during wind-up did not cancel")
	check(is_equal_approx(age.age, initial_age + 6.0), "Canceled wind-up changed the activation cost")
	await release()
	powers.clear_cooldown(GameState.ABILITY_STOP)
	await press()
	await release()
	await frames(300)
	check(TimeService.mode == TimeService.Mode.STOPPED, "Stop Time ended before its five-second window")
	await frames(40)
	check(TimeService.mode == TimeService.Mode.NORMAL and powers.active == null,
		"Stop Time did not expire automatically")
	check(powers.cooldown_left(GameState.ABILITY_STOP) > 0.0, "Automatic expiry skipped cooldown")
	check(is_equal_approx(age.age, initial_age + 9.0), "Timed activation changed its cost")
	TimeService.reset()
	if failures == 0:
		print("TIME_STOP_TOGGLE_VERIFIED: early release, held input, wind-up cancellation, five-second expiry, costs and cooldowns")
	get_tree().quit(0 if failures == 0 else 1)
