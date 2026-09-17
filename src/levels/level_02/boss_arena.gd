extends Node2D
## The room owns encounter progress; the boss owns his visible transitions.
## All waits are world-time clocks captured alongside the actors for Rewind.

enum Stage { DORMANT, FIGHTING, LEAVING, OPENING, SPAWNING, WAVE, CLOSING, RETURNING, VICTORY, COMPLETE, EXIT_WALK }

const ROOM_LEFT := 0.0
const ROOM_RIGHT := 1600.0
const ROOM_TOP := -160.0
const ROOM_BOTTOM := 920.0
const GUARD_SCENE := preload("res://src/actors/enemy/guard.tscn")
const GUNNER_SCENE := preload("res://src/actors/enemy/gunner.tscn")
const PLATFORM_TELEPORT_COOLDOWN := 4.0
const PLATFORM_SETTLE_TIME := 0.35
const PORTAL_OPEN_TIME := 0.42
const PORTAL_CLOSE_TIME := 0.28
const SPAWN_INTERVAL := 0.7
const BATTLE_MUSIC_VOLUME_DB := -19.0
const BATTLE_MUSIC := preload("res://assets/music/Epic_Boss_Battle.ogg")

var player: Player
var stage := Stage.DORMANT
var _elapsed := 0.0
var _phase_breaks := 0
var _reinforcements: Array[Enemy] = []
var _wave_count := 0
var _spawn_index := 0
var _platform_teleport_cooldown := 0.0
var _stood_on: MovingIndustrialPlatform
var _stand_time := 0.0
const PORTAL_SPAWN_GLOW_TIME := 0.6
var _portal_spawn_left := 0.0
var _shake_left := 0.0
var _shake_strength := 0.0
var _portal_clock := 0.0

@onready var cinematic: Node = $Cinematic
@onready var chamber: Node2D = $Platforms/ArenaPlatform/ParentsChamber
@onready var boss: BusinessBoss = $BusinessBoss
@onready var boss_bar: ProgressBar = $BossUI/Panel/BossHealth
@onready var boss_ui: CanvasLayer = $BossUI
@onready var reinforcement_gate: ReinforcementGate = $ReinforcementGate

func _ready() -> void:
	add_to_group(TimeService.REWINDABLE_GROUP)
	chamber.boss = boss
	cinematic.walk_finished.connect(_finish_walk)
	boss.health.changed.connect(_on_boss_health_changed)
	boss.defeated.connect(_on_boss_defeated)
	boss.health.died.connect(_on_boss_dying)
	boss.reposition_requested.connect(_on_reposition_requested)
	boss.major_impact.connect(_on_major_impact)
	_on_boss_health_changed(boss.health.current, boss.health.max_health)
	_sync_presentation()

func prepare_gate_entry(entry_player: Player) -> void:
	player = entry_player
	_configure_camera()
	if stage == Stage.DORMANT:
		TimeService.start_history_window()
		boss.target = player
		_start_fight()

func is_cinematic_active() -> bool:
	return stage in [Stage.EXIT_WALK, Stage.COMPLETE]

## Spend a heart without rebuilding the room: damage, completed waves and
## surviving reinforcements remain exactly where the player left them.
func respawn_player(actor: Player) -> bool:
	if actor == null or actor != player or stage in [Stage.DORMANT, Stage.EXIT_WALK, Stage.COMPLETE]:
		return false
	var destination := _respawn_position()
	if not destination.is_finite():
		return false
	# Old rounds must not hit the new spawn. Committing the spent heart also
	# clears history, so Rewind cannot return to the already-paid death.
	for projectile in get_tree().get_nodes_in_group(TimeService.REWINDABLE_GROUP):
		if projectile is Bullet:
			TimeService.retire(projectile)
	actor.respawn_at(destination)
	actor.facing = 1 if destination.x < global_position.x + ROOM_RIGHT * 0.5 else -1
	TimeService.start_history_window()
	_restore_fight_music()
	return true

func _respawn_position() -> Vector2:
	var safest := Vector2.INF
	var best_clearance := -1.0
	for x in [150.0, 450.0, 750.0, 1050.0, 1450.0]:
		var candidate := _floor_at(x)
		if not candidate.is_finite():
			continue
		var clearance := INF
		for enemy in get_tree().get_nodes_in_group(&"enemy"):
			if not is_ancestor_of(enemy) or not enemy.health.is_alive() \
					or enemy.process_mode == Node.PROCESS_MODE_DISABLED:
				continue
			var at: Vector2 = enemy._spawn_to if enemy.state == &"Spawning" else enemy.global_position
			clearance = minf(clearance, candidate.distance_to(at))
		if clearance > best_clearance:
			best_clearance = clearance
			safest = candidate
	return safest

func _start_fight() -> void:
	# Rewind starts with controllable gameplay, never inside an input lock.
	TimeService.start_history_window()
	boss.activate()
	_enter_stage(Stage.FIGHTING)
	_start_music.call_deferred()

func _start_music() -> void:
	var song := BATTLE_MUSIC as AudioStreamOggVorbis
	song.loop = true
	MusicManager.play_music(song, 1.0, BATTLE_MUSIC_VOLUME_DB)

func _exit_tree() -> void:
	if MusicManager.current_song == BATTLE_MUSIC:
		MusicManager.stop_music(0.6)

func _physics_process(delta: float) -> void:
	if TimeService.is_rewinding():
		return
	var scaled := TimeService.world_delta(delta)
	if is_zero_approx(scaled) or stage in [Stage.DORMANT, Stage.COMPLETE, Stage.EXIT_WALK]:
		return
	_elapsed += scaled
	_portal_clock += scaled
	_portal_spawn_left = maxf(_portal_spawn_left - scaled, 0.0)
	_shake_left = maxf(_shake_left - scaled, 0.0)
	_sync_camera_shake()
	_platform_teleport_cooldown = maxf(_platform_teleport_cooldown - scaled, 0.0)
	match stage:
		Stage.FIGHTING:
			_check_phase_break()
			if stage == Stage.FIGHTING:
				_check_platform_teleport(scaled)
		Stage.LEAVING:
			if boss.phase == BusinessBoss.Phase.WAITING:
				_enter_stage(Stage.OPENING)
		Stage.OPENING:
			if _elapsed >= PORTAL_OPEN_TIME:
				_enter_stage(Stage.SPAWNING)
		Stage.SPAWNING:
			if _elapsed >= SPAWN_INTERVAL:
				if _spawn_reinforcement(_spawn_index):
					_spawn_index += 1
				_elapsed = 0.0
				if _spawn_index >= _wave_count:
					_enter_stage(Stage.WAVE)
		Stage.WAVE:
			if _living_reinforcements() == 0:
				_enter_stage(Stage.CLOSING)
		Stage.CLOSING:
			if _elapsed >= PORTAL_CLOSE_TIME:
				boss.set_combat_phase(_phase_breaks + 1)
				boss.resume_after_intermission(_return_position())
				_enter_stage(Stage.RETURNING)
		Stage.RETURNING:
			if boss.phase == BusinessBoss.Phase.FIGHTING:
				_enter_stage(Stage.FIGHTING)
		Stage.VICTORY:
			if _elapsed >= 1.15:
				_complete_encounter()
	_sync_presentation()

func _enter_stage(next: Stage) -> void:
	stage = next
	_elapsed = 0.0
	if next == Stage.OPENING:
		var audio: AudioStreamPlayer2D = $ReinforcementGate/PortalAudio
		audio.play()
	_sync_presentation()

func _check_phase_break() -> void:
	# Hits still count during Stop Time. Keep the visible boss vulnerable;
	# the next running physics tick starts the pending health break.
	if TimeService.is_world_frozen():
		return
	if stage != Stage.FIGHTING or _phase_breaks >= 2 or not boss.health.is_alive():
		return
	var threshold := boss.health.max_health * float(2 - _phase_breaks) / 3.0
	if boss.health.current > threshold:
		return
	_phase_breaks += 1
	_wave_count = randi_range(3, 5)
	_spawn_index = 0
	_reinforcements.clear()
	boss.begin_intermission()
	_enter_stage(Stage.LEAVING)

func _on_boss_health_changed(current: float, maximum: float) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = current
	# Health restoration announces the bar too, but must never start a new wave.
	if not TimeService.is_rewinding():
		_check_phase_break()

func _check_platform_teleport(delta: float) -> void:
	var platform := _platform_under_player()
	if platform != _stood_on:
		_stood_on = platform
		_stand_time = 0.0
	if not is_instance_valid(player) or not player.is_on_floor():
		_stand_time = 0.0
		return
	_stand_time += delta
	if _stand_time < PLATFORM_SETTLE_TIME or _platform_teleport_cooldown > 0.0:
		return
	# Track the landing throughout an attack, but wait for its recovery to end.
	if boss.state in [&"Attack", &"Recover", &"Hurt"]:
		return
	if platform == null:
		# Once the player leaves the decks, bring the stationary boss back to
		# the floor instead of leaving him shooting over the player's head.
		if boss.global_position.y < reinforcement_gate.global_position.y - 60.0:
			if boss.teleport_to_floor(_return_position()):
				_platform_teleport_cooldown = PLATFORM_TELEPORT_COOLDOWN
		return
	var half_width := platform.width_tiles * 32.0
	if absf(boss.global_position.y - platform.global_position.y) < 20.0 \
			and absf(boss.global_position.x - platform.global_position.x) < half_width:
		return
	var side := -1.0 if player.global_position.x >= platform.global_position.x else 1.0
	var offset := Vector2(side * maxf(half_width - 44.0, 0.0), -1.0)
	if boss.teleport_to_platform(platform, offset):
		_platform_teleport_cooldown = PLATFORM_TELEPORT_COOLDOWN

func _on_reposition_requested() -> void:
	if stage != Stage.FIGHTING or not is_instance_valid(player):
		return
	var platform := _platform_under_player()
	var moved := false
	if platform != null:
		var side := -1.0 if player.global_position.x >= platform.global_position.x else 1.0
		moved = boss.teleport_to_platform(platform, Vector2(side * (platform.width_tiles * 32.0 - 44.0), -1.0))
	else:
		var player_x := to_local(player.global_position).x
		var side := -1.0 if boss.global_position.x > player.global_position.x else 1.0
		var x := clampf(player_x + side * 320.0, 80.0, ROOM_RIGHT - 80.0)
		if absf(x - player_x) < 180.0:
			x = clampf(player_x - side * 320.0, 80.0, ROOM_RIGHT - 80.0)
		var destination := _floor_at(x)
		if destination.is_finite():
			moved = boss.teleport_to_floor(destination)
	if moved:
		_platform_teleport_cooldown = PLATFORM_TELEPORT_COOLDOWN

func _on_major_impact(strength: float) -> void:
	_shake_left = 0.25
	_shake_strength = maxf(_shake_strength, strength)

func _sync_camera_shake() -> void:
	if not is_instance_valid(player):
		return
	var camera := player.get_node_or_null(^"Camera2D") as Camera2D
	if camera != null:
		camera.offset = Vector2(sin(_shake_left * 95.0), cos(_shake_left * 81.0)) * _shake_strength * (_shake_left / 0.25)
	if is_zero_approx(_shake_left):
		_shake_strength = 0.0

func rewind_began() -> void:
	for audio in [$ReinforcementGate/PortalAudio, $ReinforcementGate/SpawnAudio, $DeathAudio]:
		audio.stop()
	_restore_fight_music()

func rewind_ended() -> void:
	_restore_fight_music()

func _restore_fight_music() -> void:
	# Music follows the encounter, not a rewound sound-effect snapshot.
	# Reclaim interrupted/fading playback while keeping a live song in place.
	if stage not in [Stage.DORMANT, Stage.EXIT_WALK, Stage.COMPLETE]:
		_start_music()

## A jump passing near a deck is not a landing. Use the actual floor contact.
func _platform_under_player() -> MovingIndustrialPlatform:
	if not is_instance_valid(player) or not player.is_on_floor():
		return null
	for i in player.get_slide_collision_count():
		var contact := player.get_slide_collision(i)
		var platform := contact.get_collider() as MovingIndustrialPlatform
		if platform != null and $Platforms.is_ancestor_of(platform) and contact.get_normal().y < -0.5:
			return platform
	return null

## Choose room-local floor slots beside the portal, never relative to the
## player's far side. A terrain ray validates the landing before a unit exists.
func _spawn_reinforcement(index: int) -> bool:
	var destination := _reinforcement_destination(index)
	if not destination.is_finite():
		return false
	var enemy := (GUARD_SCENE if index % 2 == 0 else GUNNER_SCENE).instantiate() as Enemy
	enemy.name = "Wave%dUnit%d" % [_phase_breaks, index]
	enemy.position = $Reinforcements.to_local(reinforcement_gate.global_position)
	$Reinforcements.add_child(enemy)
	_reinforcements.append(enemy)
	enemy.target = player
	enemy.begin_spawn(reinforcement_gate.global_position, destination)
	_portal_spawn_left = PORTAL_SPAWN_GLOW_TIME
	_on_major_impact(4.5)
	$ReinforcementGate/SpawnAudio.play()
	if enemy is Guard:
		var guard := enemy as Guard
		guard.patrol_origin_x = destination.x
		guard.territory = ROOM_RIGHT - ROOM_LEFT
	return true

func _reinforcement_destination(index: int) -> Vector2:
	for attempt in 12:
		var slot := (index + attempt) % 12
		var x := clampf(reinforcement_gate.position.x - 120.0 - slot * 100.0, 80.0, ROOM_RIGHT - 80.0)
		var destination := _floor_at(x)
		if not destination.is_finite():
			continue
		if is_instance_valid(player) and destination.distance_to(player.global_position) < 110.0:
			continue
		var occupied := false
		for enemy in _reinforcements:
			if is_instance_valid(enemy) and enemy.health.is_alive():
				var at := enemy._spawn_to if enemy.state == &"Spawning" else enemy.global_position
				if at.distance_to(destination) < 70.0:
					occupied = true
		if not occupied:
			return destination
	return Vector2.INF

func _floor_at(x: float) -> Vector2:
	var floor_y := reinforcement_gate.position.y
	var query := PhysicsRayQueryParameters2D.create(
		to_global(Vector2(x, floor_y - 32.0)), to_global(Vector2(x, floor_y + 64.0)), Enemy.WORLD_LAYER)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.position + Vector2(0.0, -1.0) if not hit.is_empty() else Vector2.INF

func _return_position() -> Vector2:
	var destination := _reinforcement_destination(2)
	return destination if destination.is_finite() else $FutureBossPosition.global_position

func _living_reinforcements() -> int:
	var living := 0
	for enemy in _reinforcements:
		# Retired pit falls retain health for Rewind but cannot hold a wave open.
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() \
				and enemy.process_mode != Node.PROCESS_MODE_DISABLED and enemy.health.is_alive():
			living += 1
	return living

func _configure_camera() -> void:
	var camera := player.get_node_or_null(^"Camera2D") as Camera2D
	if camera == null:
		return
	camera.limit_left = roundi(global_position.x + ROOM_LEFT)
	camera.limit_right = roundi(global_position.x + ROOM_RIGHT)
	camera.limit_top = roundi(global_position.y + ROOM_TOP)
	camera.limit_bottom = roundi(global_position.y + ROOM_BOTTOM)
	camera.limit_smoothed = false

func _on_boss_dying() -> void:
	# Keep the decay in the room: retiring the boss must not cut it short.
	$DeathAudio.play()

func _on_boss_defeated() -> void:
	if stage not in [Stage.VICTORY, Stage.COMPLETE]:
		_enter_stage(Stage.VICTORY)

func _complete_encounter() -> void:
	if stage != Stage.VICTORY:
		return
	_enter_stage(Stage.EXIT_WALK)
	# This is the committed end of combat. The death delay before this point
	# can still be rewound; the walk cannot be interrupted by old hazards.
	player.powers.cancel()
	for projectile in get_tree().get_nodes_in_group(&"rewindable"):
		if projectile is Bullet:
			projectile.queue_free()
	for unit in $Reinforcements.get_children():
		unit.process_mode = Node.PROCESS_MODE_DISABLED
		unit.hide()
	for platform in $Platforms.get_children():
		platform.set_physics_process(false)
	TimeService.start_history_window()
	cinematic.start(player, chamber)

func _finish_walk() -> void:
	if stage != Stage.EXIT_WALK:
		return
	_enter_stage(Stage.COMPLETE)
	var level := get_parent().get_parent() as Level
	if level != null:
		level.complete()

func _process(_delta: float) -> void:
	# Rewind restores enemies after the room; refresh the count after all of
	# those snapshots, so the label never shows the abandoned future's count.
	_sync_presentation()
	for audio in [$ReinforcementGate/PortalAudio, $ReinforcementGate/SpawnAudio, $DeathAudio]:
		audio.stream_paused = TimeService.is_world_frozen()

func _sync_presentation() -> void:
	boss_ui.visible = stage not in [Stage.DORMANT, Stage.EXIT_WALK, Stage.COMPLETE]
	$BossUI/Panel/Result.visible = stage == Stage.COMPLETE
	var status: Label = $BossUI/Panel/Status
	var in_wave := stage in [Stage.LEAVING, Stage.OPENING, Stage.SPAWNING, Stage.WAVE, Stage.CLOSING]
	boss_bar.self_modulate.a = 0.4 if in_wave else 1.0
	status.modulate = Color(0.55, 0.85, 1.0)
	if in_wave:
		status.text = "REINFORCEMENTS REMAINING: %d" % (_living_reinforcements() + _wave_count - _spawn_index)
	elif stage in [Stage.VICTORY, Stage.COMPLETE]:
		status.text = ""
	elif is_instance_valid(boss):
		var pattern: String = ["SINGLE SHOT", "3-SHOT BURST", "TELEPORT + 2 SHOTS"][boss.combat_phase - 1]
		status.text = "PHASE %d - %s" % [boss.combat_phase, pattern]
		if boss.phase == BusinessBoss.Phase.RECOVERING or boss.state == &"Recover":
			status.text = "COUNTERATTACK"
			status.modulate = Color(0.6, 1.0, 0.65)
	var opening := 0.0
	match stage:
		Stage.OPENING: opening = _elapsed / PORTAL_OPEN_TIME
		Stage.SPAWNING, Stage.WAVE: opening = 1.0
		Stage.CLOSING: opening = 1.0 - _elapsed / PORTAL_CLOSE_TIME
	reinforcement_gate.set_open_fraction(opening, _portal_clock, _portal_spawn_left / PORTAL_SPAWN_GLOW_TIME)

func rewind_capture() -> Array:
	return [stage, _elapsed, _phase_breaks, _wave_count, _spawn_index,
		_reinforcements.duplicate(), _platform_teleport_cooldown, _stood_on, _stand_time, _shake_left, _shake_strength, _portal_clock, _portal_spawn_left]

func rewind_apply(saved: Array) -> void:
	stage = saved[0]
	_elapsed = saved[1]
	_phase_breaks = saved[2]
	_wave_count = saved[3]
	_spawn_index = saved[4]
	_reinforcements.assign(saved[5])
	_platform_teleport_cooldown = saved[6]
	_stood_on = saved[7]
	_stand_time = saved[8]
	_shake_left = saved[9]
	_shake_strength = saved[10]
	_portal_clock = saved[11]
	_portal_spawn_left = saved[12]
	_sync_camera_shake()
	_sync_presentation()
