extends "res://tests/level_02/verify_boss_retries.gd"
## The Manager's three telekinetic moves: Repulse, Pulse and Volley, with the
## world clock and Rewind. Run with --headless --fixed-fps 60.

## His hazards live under the current scene - this node - so a fresh fight
## starts with the last one's cleared away.
func fresh(start_encounter := true) -> void:
	for node in get_tree().get_nodes_in_group(&"business_hazard"):
		node.queue_free()
	await super.fresh(start_encounter)


func floor_at(x: float) -> Vector2:
	return arena._floor_at(x)

func park(offset_x: float) -> void:
	player.global_position = floor_at(arena.to_local(boss.global_position).x + offset_x)
	player.velocity = Vector2.ZERO

## Holds the boy still where he is, but still there to be hit: a disabled
## body leaves the physics space unless told to stay.
func hold_still(held: bool) -> void:
	player.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE
	player.process_mode = Node.PROCESS_MODE_DISABLED if held else Node.PROCESS_MODE_INHERIT


## Live hazards of one kind: "BusinessPulse" or "BusinessShard".
func hazards(kind: String) -> Array:
	var found := []
	for node in get_tree().get_nodes_in_group(&"business_hazard"):
		var wanted: bool = node is BusinessPulse if kind == "BusinessPulse" else node is BusinessShard
		if wanted and node.process_mode != Node.PROCESS_MODE_DISABLED:
			found.append(node)
	return found

func wait_state(wanted: StringName, limit: int) -> bool:
	for i in limit:
		if boss.state == wanted:
			return true
		await frames(1)
	return false


## A boy at his hip is thrown clear; the cooldown keeps it from being a wall.
func repulse_close() -> void:
	await fresh()
	park(-80.0)
	check(await wait_state(&"Repulse", 150), "Standing at his hip did not draw a Repulse")
	for i in 30:
		if boss._burst_done:
			break
		await frames(1)
	var before := player.health.current + BusinessBoss.REPULSE_DAMAGE
	check(boss._burst_done and player.states.current_name == &"Hurt", "The burst did not stagger the boy")
	check(player.launch == Vector2.ZERO and player.velocity.x < -400.0, "The burst did not launch him away: %s" % player.velocity)
	await frames(30)
	check(absf(player.global_position.x - boss.global_position.x) > 250.0, "He was not thrown clear: %.0f" % absf(player.global_position.x - boss.global_position.x))
	check(is_equal_approx(player.health.current, before - BusinessBoss.REPULSE_DAMAGE), "Repulse damage was not %s" % BusinessBoss.REPULSE_DAMAGE)
	check(boss._repulse_cooldown > 3.0, "No cooldown after the burst")
	# Straight back at his hip: nothing until the cooldown runs out.
	for i in 60:
		park(-80.0)
		await frames(1)
		check(boss.state != &"Repulse", "Repulse repeated inside its cooldown")
	print("BOSS_MOVES repulse: standing close is thrown clear, once per cooldown")


## Three hits in a row are answered as soon as his hands are free, however
## far the boy has stepped back since.
func repulse_hits() -> void:
	await fresh()
	park(-400.0)
	for i in BusinessBoss.REPULSE_HITS:
		boss.receive_player_hit(34.0, player)
	check(boss.health.current < BusinessBoss.BOSS_HEALTH, "The hits did not land")
	check(await wait_state(&"Repulse", 120), "Three hits did not draw a Repulse, state %s" % boss.state)
	check(is_zero_approx(boss._close_time), "The Repulse came from the close timer, not the hits")
	print("BOSS_MOVES repulse: three quick hits are answered at once")


## Sends one pulse train with the gaps forced, and returns its pulses once
## `wanted_count` of them are out. Pulses already in the room are not his.
func pulse_train(gaps: Array, wanted_count := BusinessBoss.PULSE_COUNT) -> Array:
	var old := hazards("BusinessPulse")
	boss._change_state(&"Pulse")
	var sent := []
	var forced := gaps.duplicate()
	for i in 200:
		await frames(1)
		for pulse in hazards("BusinessPulse"):
			if not sent.has(pulse) and not old.has(pulse):
				sent.append(pulse)
				if not forced.is_empty():
					# Re-send it with the gap this case wants.
					var wanted: BusinessPulse.Gap = forced.pop_front()
					pulse.send(pulse.global_position, pulse.global_position.y, pulse.direction, wanted, pulse.left_bound, pulse.right_bound)
		if sent.size() >= wanted_count:
			break
	return sent


## Waves cross the room from his head in a train; a standing boy is hit,
## a crouched one passes a low gap and a jumping one a high gap; a stop
## holds the train.
func pulse() -> void:
	await fresh()
	boss.set_combat_phase(2)
	boss.attack_recovery = 99.0
	park(-560.0)
	var before := player.health.current
	var sent := await pulse_train([BusinessPulse.Gap.LOW, BusinessPulse.Gap.LOW, BusinessPulse.Gap.LOW])
	check(sent.size() == BusinessBoss.PULSE_COUNT, "Phase two sent %d pulses" % sent.size())
	if sent.is_empty():
		return
	var first: BusinessPulse = sent[0]
	check(absf(first.global_position.y - boss.global_position.y) < 2.0 and first.direction < 0.0, "The pulse did not leave along the floor toward the boy")
	for i in 120:
		if first._spent:
			break
		await frames(1)
	check(first._spent, "A standing boy was not hit by a low-gap pulse")
	check(player.health.current <= before - BusinessPulse.DAMAGE, "The pulse did not cost %s" % BusinessPulse.DAMAGE)
	# Crouched under a low gap: the train passes over him.
	await fresh()
	boss.set_combat_phase(2)
	boss.attack_recovery = 99.0
	park(-560.0)
	player.set_crouched(true)
	hold_still(true)
	before = player.health.current
	sent = await pulse_train([BusinessPulse.Gap.LOW, BusinessPulse.Gap.LOW, BusinessPulse.Gap.LOW])
	await frames(150)
	check(is_equal_approx(player.health.current, before), "A crouched boy was hit through a low gap")
	# The same crouch under a high gap is hit: the gap has to be read.
	before = player.health.current
	sent = await pulse_train([BusinessPulse.Gap.HIGH, BusinessPulse.Gap.HIGH, BusinessPulse.Gap.HIGH])
	await frames(150)
	check(player.health.current < before, "A crouched boy passed a high gap")
	hold_still(false)
	player.set_crouched(false)
	# Held in the air at a jump's height under a high gap: also clear.
	await fresh()
	boss.set_combat_phase(2)
	boss.attack_recovery = 99.0
	park(-560.0)
	player.global_position.y -= 130.0
	hold_still(true)
	before = player.health.current
	sent = await pulse_train([BusinessPulse.Gap.HIGH, BusinessPulse.Gap.HIGH, BusinessPulse.Gap.HIGH])
	await frames(150)
	check(is_equal_approx(player.health.current, before), "A jumping boy was hit through a high gap")
	# And in the air under a low one: hit.
	sent = await pulse_train([BusinessPulse.Gap.LOW, BusinessPulse.Gap.LOW, BusinessPulse.Gap.LOW])
	await frames(150)
	check(player.health.current < before, "A boy in the air passed a low gap")
	hold_still(false)
	# Stopped time holds the train where it is.
	await fresh()
	boss.set_combat_phase(2)
	boss.attack_recovery = 99.0
	park(-560.0)
	sent = await pulse_train([])
	var wave: BusinessPulse = sent[0]
	TimeService.mode = TimeService.Mode.STOPPED
	var x := wave.global_position.x
	await frames(20)
	check(is_equal_approx(wave.global_position.x, x), "A stopped pulse kept moving")
	TimeService.mode = TimeService.Mode.NORMAL
	await frames(8)
	check(wave.global_position.x < x - 20.0, "The pulse did not resume with time")
	print("BOSS_MOVES pulse: trains from his head, gaps read by crouch or jump, held by a stop")


## Phase three lifts three shards, holds them harmless, then throws them at
## where the boy stands.
func volley() -> void:
	await fresh()
	boss.set_combat_phase(3)
	boss.attack_recovery = 99.0
	park(-520.0)
	boss._change_state(&"Volley")
	await frames(2)
	var shards := hazards("BusinessShard")
	check(shards.size() == 3, "Volley lifted %d shards" % shards.size())
	if shards.size() != 3:
		return
	var before := player.health.current
	# Held shards are harmless: stand in one.
	await frames(20)
	var held: BusinessShard = shards[0]
	check(held.stage in [BusinessShard.Stage.RISING, BusinessShard.Stage.HELD] and not held.monitoring, "A held shard is armed")
	var parked := player.global_position
	player.global_position = held.global_position
	await frames(3)
	check(is_equal_approx(player.health.current, before), "A held shard hurt him")
	player.global_position = parked
	player.velocity = Vector2.ZERO
	# The throws, one per gap, each at where he stood at the moment.
	for i in 60:
		if boss._thrown == 1:
			break
		await frames(1)
	check(boss._thrown == 1 and held.stage == BusinessShard.Stage.THROWN, "First shard not thrown after the rise")
	var aim := player.global_position
	player.global_position.y -= 200.0
	player.process_mode = Node.PROCESS_MODE_DISABLED
	await frames(int(BusinessShard.FLIGHT_TIME * 60.0) + 12)
	check(held.stage == BusinessShard.Stage.SPENT, "First shard did not land")
	check(absf(held.global_position.x - aim.x) < 60.0, "First shard landed %.0f px from where he stood" % absf(held.global_position.x - aim.x))
	for shard in shards:
		check(shard.stage in [BusinessShard.Stage.THROWN, BusinessShard.Stage.SPENT], "A shard was never thrown")
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.global_position = aim
	await frames(30)
	check(boss.state == &"Recover" and boss._shards.is_empty(), "Volley did not end in Recover with the hold released")
	# A thrown shard hurts.
	await fresh()
	boss.set_combat_phase(3)
	boss.attack_recovery = 99.0
	park(-520.0)
	boss._change_state(&"Volley")
	before = player.health.current
	await frames(150)
	check(player.health.current <= before - BusinessShard.DAMAGE, "No thrown shard reached a standing boy")
	print("BOSS_MOVES volley: three shards rise harmless, then land where he stood")


## Rewind puts a spent pulse back in the air and held shards back in the hold.
func rewind() -> void:
	await fresh()
	boss.set_combat_phase(3)
	boss.attack_recovery = 99.0
	park(-520.0)
	boss._change_state(&"Volley")
	await frames(40)
	var shards := hazards("BusinessShard")
	check(shards.size() == 3, "Setup: %d shards" % shards.size())
	if shards.size() != 3:
		return
	var held: BusinessShard = shards[0]
	var high := held.global_position
	await frames(60)
	check(held.stage == BusinessShard.Stage.THROWN or held.stage == BusinessShard.Stage.SPENT, "Setup: shard never thrown")
	# A second back: past the throw, not past the lift (rewind runs at 2.5x).
	await rewind_ticks(24)
	check(held.stage == BusinessShard.Stage.HELD and held.global_position.distance_to(high) < 12.0, "Rewind did not put the shard back in his hold: %s at %s" % [held.stage, held.global_position])
	check(boss.state == &"Volley" and boss._thrown == 0, "Rewind did not restore the volley: %s thrown %d" % [boss.state, boss._thrown])
	await fresh()
	boss.set_combat_phase(2)
	boss.attack_recovery = 99.0
	park(-300.0)
	var sent := await pulse_train([BusinessPulse.Gap.LOW], 1)
	var wave: BusinessPulse = sent[0]
	var born: float = TimeService._now
	for i in 90:
		if wave._spent:
			break
		await frames(1)
	check(wave._spent, "Setup: pulse never landed")
	# Back to a moment shortly after it was sent, at the rewind's 2.5x.
	await rewind_ticks(ceili((TimeService._now - born - 0.15) * 60.0 / TimeService.REWIND_SPEED))
	check(is_instance_valid(wave) and not wave._spent and wave.visible and wave.process_mode != Node.PROCESS_MODE_DISABLED, "Rewind did not put the pulse back in the air")
	print("BOSS_MOVES rewind: shards return to the hold, a spent pulse to the air")


## A spent heart clears the room of his hazards before the boy is put back.
func respawn() -> void:
	await fresh()
	boss.set_combat_phase(2)
	boss.attack_recovery = 99.0
	park(-560.0)
	var sent := await pulse_train([])
	var wave: BusinessPulse = sent[0]
	player.health.kill(boss)
	await confirm_death()
	check(not is_instance_valid(wave) or wave.process_mode == Node.PROCESS_MODE_DISABLED, "A pulse survived the respawn")
	print("BOSS_MOVES respawn: hazards are cleared with the spent heart")


func _ready() -> void:
	await repulse_close()
	await repulse_hits()
	await pulse()
	await volley()
	await rewind()
	await respawn()
	print("BOSS_MOVES_VERIFIED failures=%d" % failures)
	TimeService.reset()
	level.queue_free()
	await frames(2)
	get_tree().quit(1 if failures else 0)
