extends Node
## Real arena physics and TimeService playback. Run with --headless --fixed-fps 60.

const MAP := preload("res://src/levels/level_02/level_02.tscn")
var level: Level
var player: Player
var arena: Node2D
var boss: BusinessBoss
var failures := 0
var completions := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func fresh(start_encounter := true) -> void:
	TimeService.reset()
	for child in get_children():
		if child is Bullet:
			child.queue_free()
	if is_instance_valid(level):
		level.queue_free()
	await frames(2)
	GameState.clear_run_progress()
	level = MAP.instantiate()
	level.debug_spawn_path = NodePath()
	add_child(level)
	get_tree().current_scene = self
	player = level.get_node("Entities/Player")
	arena = level.get_node("World/BossArena")
	boss = arena.boss
	level.get_node("Enemies").process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("World/Hazards").process_mode = Node.PROCESS_MODE_DISABLED
	EventBus.player_died.disconnect(level._on_player_died)
	player.health.max_health = 100000.0
	player.health.restore_to(100000.0)
	player.global_position = arena.to_global(Vector2(150, 640))
	if start_encounter:
		arena.prepare_gate_entry(player)
	await frames(120)

func rewind_ticks(count: int) -> void:
	TimeService.mode = TimeService.Mode.REWINDING
	await frames(count)
	TimeService.mode = TimeService.Mode.NORMAL
	await frames(2)

func wait_stage(wanted: int, limit := 600) -> void:
	for i in limit:
		if arena.stage == wanted:
			return
		await frames(1)
	check(false, "Arena did not reach stage %s, at %s" % [wanted, arena.stage])

func clear_wave() -> void:
	for enemy in arena._reinforcements:
		if is_instance_valid(enemy):
			enemy.health.kill(player)

func entry_history() -> void:
	await fresh(false)
	player.global_position = Vector2(800, 640)
	await frames(120)
	var retired: Enemy = level.get_node("Enemies/StreetPatrol")
	TimeService.retire(retired)
	player.global_position = arena.to_global(Vector2(150, 640))
	arena.prepare_gate_entry(player)
	await frames(20)
	check(not is_instance_valid(retired), "Entry history reset retained an orphaned corpse")
	await rewind_ticks(90)
	check(player.global_position.x >= arena.global_position.x, "Rewind escaped behind the consumed entrance gate")
	check(arena.stage == arena.Stage.FIGHTING, "Entry rewind deactivated the fight")

func spawning() -> void:
	await fresh()
	for x in [150.0, 1510.0]:
		player.global_position = arena.to_global(Vector2(x, 640))
		check(arena._spawn_reinforcement(arena._reinforcements.size()), "No valid portal exit")
	var enemy: Enemy = arena._reinforcements[0]
	await frames(12)
	check(enemy.state == &"Spawning" and enemy.collision_layer == 0, "Spawn enabled combat too early")
	var health := enemy.health.current
	# Use the player's actual distance-based sword hit; collision layers alone
	# cannot make a spawning unit invulnerable.
	player.global_position = enemy.global_position + Vector2(-20.0, 0.0)
	player.facing = 1
	player.consume_attack()
	player.perform_attack_hit()
	check(enemy.health.current == health, "Sword hurt a spawning reinforcement")
	TimeService.mode = TimeService.Mode.STOPPED
	var position_before := enemy.global_position
	var scale_before := enemy.scale
	await frames(60)
	check(enemy.global_position == position_before and enemy.scale == scale_before, "Spawn moved during Stop Time")
	TimeService.mode = TimeService.Mode.NORMAL
	player.global_position = arena.to_global(Vector2(150, 640))
	await frames(45)
	for unit in arena._reinforcements:
		check(unit.is_on_floor(), "Reinforcement did not land on the arena floor")
		check(unit.scale == Vector2.ONE and unit.collision_layer == 4, "Reinforcement failed to activate")
		check(arena.to_local(unit.global_position).x > 0.0 and arena.to_local(unit.global_position).x < 1600.0, "Reinforcement escaped the walls")
	# A pit retirement keeps a healthy body in history; it must not block waves.
	for unit in arena._reinforcements:
		unit.global_position.y = unit._spawn_y + Enemy.PIT_DEPTH + 10.0
	await frames(3)
	check(arena._living_reinforcements() == 0, "Retired pit fall blocks wave completion")
	print("BOSS spawning: boundaries, immunity, freeze, landing, pit retirement")

func spawn_rewind() -> void:
	await fresh()
	check(arena._spawn_reinforcement(0), "Spawn rewind fixture could not spawn")
	var enemy: Enemy = arena._reinforcements[0]
	await frames(42)
	check(enemy.state != &"Spawning", "Spawn did not finish before rewind")
	await rewind_ticks(10)
	check(enemy.state == &"Spawning" and enemy.scale.x < 0.9 and enemy.collision_layer == 0, "Rewind did not restore partial spawn scale and immunity")
	await frames(45)
	check(enemy.scale == Vector2.ONE and enemy.collision_layer == 4 and enemy.is_on_floor(), "Rewound spawn failed to resume")

func teleports() -> void:
	await fresh()
	var platform: MovingIndustrialPlatform = arena.get_node("Platforms/StepOne")
	player.global_position = platform.global_position + Vector2(20.0, -35.0)
	player.velocity = Vector2(0.0, -200.0)
	await frames(1)
	check(arena._platform_under_player() == null, "Passing a platform counted as standing on it")
	# Direct transition allows an exact check of immunity and world-time pause.
	var offset := Vector2(-50.0, -1.0)
	check(boss.teleport_to_platform(platform, offset), "Teleport did not start")
	arena._platform_teleport_cooldown = arena.PLATFORM_TELEPORT_COOLDOWN
	await frames(12)
	var hp := boss.health.current
	player.global_position = boss.global_position + Vector2(-20.0, 0.0)
	player.facing = 1
	player.consume_attack()
	player.perform_attack_hit()
	check(boss.health.current == hp, "Sword hurt the disappearing boss")
	TimeService.mode = TimeService.Mode.STOPPED
	var phase_elapsed := boss._phase_elapsed
	var opacity := boss.sprite.self_modulate.a
	await frames(60)
	check(boss._phase_elapsed == phase_elapsed and boss.sprite.self_modulate.a == opacity, "Teleport/effect advanced during Stop Time")
	TimeService.mode = TimeService.Mode.NORMAL
	player.global_position = arena.to_global(Vector2(150, 640))
	for i in 120:
		if boss.phase == BusinessBoss.Phase.RECOVERING:
			break
		await frames(1)
	check(boss.phase == BusinessBoss.Phase.RECOVERING, "Teleport skipped arrival recovery")
	check(boss.global_position.distance_to(platform.global_position + offset) < 5.0, "Boss landed at an outdated moving-platform position")
	await frames(12)
	check(boss.phase == BusinessBoss.Phase.RECOVERING and boss.is_on_floor(), "Boss failed to stay on the deck during recovery")
	await frames(40)
	check(boss.phase == BusinessBoss.Phase.FIGHTING, "Boss failed to resume combat")
	# Normal arena logic must bring him back when the player stays on the floor.
	await frames(360)
	check(absf(boss.global_position.y - arena.reinforcement_gate.global_position.y) < 5.0, "Boss stayed stranded on a platform")
	# A higher-priority health break must replace a teleport, never race it.
	boss.teleport_to_platform(platform, offset)
	boss.health.take_damage(450.0, player)
	await frames(60)
	check(boss.phase == BusinessBoss.Phase.WAITING and not boss.sprite.visible and boss.collision_layer == 0, "Old teleport revived an intermission boss")
	print("BOSS teleport: floor contact, immunity, freeze, moving landing, recovery, floor return, interruption")
	await fresh()
	platform = arena.get_node("Platforms/StepOne")
	player.global_position = platform.global_position + Vector2(35.0, -3.0)
	player.velocity = Vector2.ZERO
	for i in 150:
		if boss.phase == BusinessBoss.Phase.DISAPPEARING:
			break
		await frames(1)
	check(boss.phase == BusinessBoss.Phase.DISAPPEARING, "Actual platform landing did not trigger teleport")
	await rewind_ticks(40)
	check(boss.phase == BusinessBoss.Phase.FIGHTING and boss.collision_layer == 4, "Rewind did not undo platform teleport")

func waves_and_rewind() -> void:
	await fresh()
	boss.receive_player_hit(450.0, player)
	await wait_stage(arena.Stage.OPENING)
	await frames(10)
	TimeService.mode = TimeService.Mode.STOPPED
	var portal_scale: Vector2 = Vector2(arena.reinforcement_gate.open_fraction, arena.reinforcement_gate.visual_time)
	await frames(40)
	check(Vector2(arena.reinforcement_gate.open_fraction, arena.reinforcement_gate.visual_time) == portal_scale, "Portal opened during Stop Time")
	TimeService.mode = TimeService.Mode.NORMAL
	await wait_stage(arena.Stage.SPAWNING)
	for i in 90:
		if not arena._reinforcements.is_empty():
			break
		await frames(1)
	await frames(10)
	await rewind_ticks(95)
	check(arena.stage == arena.Stage.FIGHTING and arena._phase_breaks == 0, "Rewind did not restore pre-break arena state")
	check(boss.phase == BusinessBoss.Phase.FIGHTING and boss.health.current == 1200.0 and boss.sprite.visible, "Rewind did not restore pre-break boss")
	check(arena.get_node("Reinforcements").get_child_count() == 0, "Abandoned wave survived Rewind")
	await frames(100)
	check(arena.stage == arena.Stage.FIGHTING, "Abandoned callback reopened the portal")
	boss.receive_player_hit(450.0, player)
	await wait_stage(arena.Stage.WAVE)
	await frames(45)
	await frames(120)
	check(arena._reinforcements.size() >= 3 and arena._reinforcements.size() <= 5, "Wrong wave size")
	clear_wave()
	await wait_stage(arena.Stage.RETURNING)
	await frames(8)
	await rewind_ticks(35)
	check(arena.stage == arena.Stage.WAVE and arena._living_reinforcements() > 0, "Rewind across wave clear did not revive the wave")
	check(boss.phase == BusinessBoss.Phase.WAITING and not boss.sprite.visible, "Rewind across return left boss visible")
	clear_wave()
	await wait_stage(arena.Stage.FIGHTING)
	check(arena._phase_breaks == 1 and boss.combat_phase == 2 and boss.collision_layer == 4, "First wave did not return boss")
	boss.receive_player_hit(400.0, player)
	await wait_stage(arena.Stage.WAVE)
	await frames(45)
	clear_wave()
	await wait_stage(arena.Stage.FIGHTING)
	check(arena._phase_breaks == 2 and boss.combat_phase == 3, "Second wave missing or phase did not advance")
	boss.receive_player_hit(34.0, player)
	await frames(60)
	check(arena.stage == arena.Stage.FIGHTING, "Third health segment started another wave")
	print("BOSS waves: portal freeze, rewind before spawn/after clear, two full waves")

func death_and_rewind() -> void:
	await fresh()
	boss.health.kill(player)
	await frames(45)
	check(arena.stage == arena.Stage.VICTORY, "Boss death did not start victory delay")
	await rewind_ticks(40)
	check(boss.health.is_alive() and boss.sprite.visible and boss.phase == BusinessBoss.Phase.FIGHTING, "Rewind did not revive boss after explosion")
	check(arena.stage == arena.Stage.FIGHTING, "Rewind did not cancel victory")
	await frames(150)
	check(completions == 0 and player.process_mode != Node.PROCESS_MODE_DISABLED, "Abandoned victory completed level")
	boss.health.kill(player)
	TimeService.mode = TimeService.Mode.STOPPED
	await frames(60)
	check(boss.phase == BusinessBoss.Phase.DYING, "Death transition ignored Stop Time")
	TimeService.mode = TimeService.Mode.NORMAL
	await wait_stage(arena.Stage.COMPLETE, 1200)
	await frames(60)
	check(completions == 1, "Victory did not complete exactly once")
	print("BOSS death: freeze, revival, cancelled victory, single completion")

func _ready() -> void:
	EventBus.level_completed.connect(func(_id: StringName): completions += 1)
	await entry_history()
	await spawning()
	await spawn_rewind()
	await teleports()
	await waves_and_rewind()
	await death_and_rewind()
	print("BUSINESS_BOSS_VERIFIED failures=%d" % failures)
	TimeService.reset()
	level.queue_free()
	await frames(2)
	get_tree().quit(1 if failures else 0)
