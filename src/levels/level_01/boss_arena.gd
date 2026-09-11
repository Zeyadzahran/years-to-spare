class_name BossArena
extends Node2D
## Encounter orchestration for the existing inline room. Geometry and art stay
## authored in level_01.tscn; this only starts the boss, emits learned rock
## patterns, admits bounded reinforcement groups, and runs the victory walk.

const ROCK_SCENE := preload("res://src/levels/level_01/boss_rock.tscn")
const IMPACT_SCENE := preload("res://src/levels/level_01/boss_impact_effect.tscn")
const SHOCKWAVE_SCENE := preload("res://src/levels/level_01/boss_shockwave.tscn")
const GUARD_SCENE := preload("res://src/actors/enemy/guard.tscn")
## The only music in the level. It starts under the wake-up roar and is gone
## by the time the titan has finished falling, so the walk up to the sister
## happens in the quiet the room had before.
const BOSS_MUSIC: AudioStream = preload("res://assets/music/Epic_Boss_Battle.ogg")
const MUSIC_VOLUME_DB := -7.0

const ROOM_LEFT := 2500.0
const ROOM_RIGHT := 4820.0
const ROOM_TOP := -420.0
const ROOM_BOTTOM := 600.0
const FLOOR_Y := 481.0
const BOSS_LEFT := 2700.0
# Keep the body inside the right wall while allowing it to pursue the player
# throughout the combat floor beneath the sister platform.
const BOSS_RIGHT := 4680.0
const MAX_REINFORCEMENT_WAVES := 2

@onready var activation: Area2D = $Activation
@onready var boss: StoneTitan = $StoneTitan
@onready var hazards: Node2D = $StompHazards
@onready var arena_adds: Node2D = $ArenaAdds
@onready var staircase: Node2D = $SisterArea/Staircase
@onready var fade: ColorRect = $Outro/Fade
@onready var sister: AnimatedSprite2D = $TrappedSister

var player: Player
var _started := false
var _victory := false
var _pending_rocks: Array[BossRock] = []
var _reinforcement_wave := 0
var _warning_phase := 1
var _camera_rig: BossCameraRig
var _screen_fx: BossScreenFx


func _ready() -> void:
	_hide_staircase()
	activation.body_entered.connect(_on_activation_body_entered)
	boss.stomp_warning.connect(_on_stomp_warning)
	boss.stomp_impact.connect(_on_stomp_impact)
	boss.defeated.connect(_on_boss_defeated)
	fade.color.a = 0.0
	for body in activation.get_overlapping_bodies():
		if body is Player:
			_on_activation_body_entered(body)


func _on_activation_body_entered(body: Node2D) -> void:
	if _started or not body is Player:
		return
	player = body
	_started = true
	_configure_camera()
	# The rig and the screen layer go in before the titan wakes, because the
	# wake-up is the first thing that uses them.
	_camera_rig = BossCameraRig.attach(player.get_node_or_null(^"Camera2D") as Camera2D)
	_screen_fx = BossScreenFx.new()
	_screen_fx.name = &"ScreenFx"
	add_child(_screen_fx)
	_start_music()
	boss.activate(player, global_position.x + BOSS_LEFT, global_position.x + BOSS_RIGHT)


func _start_music() -> void:
	# Looped here rather than in the import, so the setting travels with the
	# code that depends on it.
	var song := BOSS_MUSIC as AudioStreamOggVorbis
	song.loop = true
	# A slow swell: the roar owns the first two seconds.
	MusicManager.play_music(BOSS_MUSIC, 2.6, MUSIC_VOLUME_DB)


func _exit_tree() -> void:
	# A death reloads the level with the manager still playing; the normal
	# level has no music, and the boss theme must not follow the boy back
	# to his checkpoint.
	if MusicManager.current_song == BOSS_MUSIC:
		MusicManager.stop_music(0.8)


func _configure_camera() -> void:
	var camera := player.get_node_or_null(^"Camera2D") as Camera2D
	if camera == null:
		return
	camera.limit_left = roundi(global_position.x + ROOM_LEFT)
	camera.limit_right = roundi(global_position.x + ROOM_RIGHT)
	camera.limit_top = roundi(global_position.y + ROOM_TOP)
	camera.limit_bottom = roundi(global_position.y + ROOM_BOTTOM)
	camera.limit_smoothed = true


func _on_stomp_warning(stomp_number: int, phase: int) -> void:
	_clear_pending_rocks()
	_warning_phase = phase
	match (stomp_number - 1) % 5:
		0: _prepare_falling_pattern(phase, stomp_number)
		1: _prepare_eruption_pattern(phase, stomp_number)
		2: _prepare_large_impact_pattern(phase, stomp_number)
		3: _prepare_alternating_pattern(phase, stomp_number)
		_: _prepare_mixed_size_pattern(phase, stomp_number)
	if _should_call_reinforcements(stomp_number):
		_spawn_reinforcements()


func _on_stomp_impact(stomp_number: int, phase: int) -> void:
	for rock in _pending_rocks:
		if is_instance_valid(rock):
			rock.launch()
	_pending_rocks.clear()
	var powerful := (stomp_number - 1) % 5 == 2
	var impact := IMPACT_SCENE.instantiate() as BossImpactEffect
	hazards.add_child(impact)
	impact.configure(Vector2(boss.global_position.x, to_global(Vector2(0.0, FLOOR_Y)).y),
		1.35 if powerful else 1.0, true)
	_spawn_shockwaves(stomp_number, phase, powerful)
	_slam_feedback(powerful)


## What the slam does to the picture. The floor ring and dust are the
## impact effect's; this is the camera dropping with the foot, the frame
## flashing and a shockwave running out through the image.
func _slam_feedback(powerful: bool) -> void:
	var foot := Vector2(boss.global_position.x, to_global(Vector2(0.0, FLOOR_Y)).y)
	if _camera_rig != null and is_instance_valid(_camera_rig):
		_camera_rig.add_trauma(0.8 if powerful else 0.6)
		_camera_rig.kick(Vector2(0.0, 14.0 if powerful else 9.0))
		_camera_rig.punch_zoom(0.065 if powerful else 0.04, 0.38)
	if _screen_fx != null and is_instance_valid(_screen_fx):
		_screen_fx.shockwave(foot, 1.0 if powerful else 0.75)
		_screen_fx.flash(Color(1.0, 0.82, 0.55), 0.22 if powerful else 0.12, 7.0)


func _prepare_falling_pattern(phase: int, stomp_number: int) -> void:
	var target_x := _player_target_x()
	var inward := _inward_direction(target_x)
	# The first marker is directly under the player. The remaining falling
	# stones trail toward the room centre, leaving the outer side as an escape.
	_arm_vertical_rock(target_x, BossRock.RockSize.MEDIUM,
		BossRock.MotionKind.FALL, 0.0, stomp_number)
	_arm_vertical_rock(target_x + inward * 185.0, BossRock.RockSize.SMALL,
		BossRock.MotionKind.FALL, 0.1, stomp_number + 1)
	_arm_vertical_rock(target_x + inward * 365.0,
		BossRock.RockSize.LARGE if phase >= 2 else BossRock.RockSize.SMALL,
		BossRock.MotionKind.FALL, 0.2, stomp_number + 2)


func _prepare_eruption_pattern(phase: int, stomp_number: int) -> void:
	var target_x := _player_target_x()
	var inward := _inward_direction(target_x)
	_arm_vertical_rock(target_x, BossRock.RockSize.MEDIUM,
		BossRock.MotionKind.ERUPT, 0.0, stomp_number)
	_arm_vertical_rock(target_x + inward * 170.0, BossRock.RockSize.SMALL,
		BossRock.MotionKind.ERUPT, 0.12, stomp_number + 1)
	_arm_vertical_rock(target_x + inward * 335.0, BossRock.RockSize.SMALL,
		BossRock.MotionKind.ERUPT, 0.24, stomp_number + 2)


func _prepare_large_impact_pattern(phase: int, stomp_number: int) -> void:
	var target_x := _player_target_x()
	var inward := _inward_direction(target_x)
	var fragments := _fragment_positions(target_x, 105.0)
	_arm_vertical_rock(target_x, BossRock.RockSize.LARGE,
		BossRock.MotionKind.FALL, 0.0, stomp_number)
	_arm_vertical_rock(fragments[0], BossRock.RockSize.SMALL,
		BossRock.MotionKind.FALL, 0.18, stomp_number + 1)
	_arm_vertical_rock(fragments[1], BossRock.RockSize.SMALL,
		BossRock.MotionKind.FALL, 0.25, stomp_number + 2)
	if phase >= 3:
		_arm_vertical_rock(target_x + inward * 245.0, BossRock.RockSize.SMALL,
			BossRock.MotionKind.ERUPT, 0.38, stomp_number + 3)


func _prepare_alternating_pattern(phase: int, stomp_number: int) -> void:
	var target_x := _player_target_x()
	var alternating_positions := _fragment_positions(target_x, 190.0)
	_arm_vertical_rock(target_x, BossRock.RockSize.MEDIUM,
		BossRock.MotionKind.FALL, 0.0, stomp_number)
	_arm_vertical_rock(alternating_positions[0], BossRock.RockSize.SMALL,
		BossRock.MotionKind.ERUPT, 0.13, stomp_number + 1)
	_arm_vertical_rock(alternating_positions[1], BossRock.RockSize.SMALL,
		BossRock.MotionKind.FALL, 0.26, stomp_number + 2)


func _prepare_mixed_size_pattern(phase: int, stomp_number: int) -> void:
	var target_x := _player_target_x()
	var inward := _inward_direction(target_x)
	var fragments := _fragment_positions(target_x, 150.0)
	_arm_vertical_rock(target_x, BossRock.RockSize.LARGE,
		BossRock.MotionKind.ERUPT, 0.0, stomp_number)
	_arm_vertical_rock(fragments[0], BossRock.RockSize.SMALL,
		BossRock.MotionKind.FALL, 0.12, stomp_number + 1)
	_arm_vertical_rock(fragments[1], BossRock.RockSize.SMALL,
		BossRock.MotionKind.FALL, 0.24, stomp_number + 2)
	if phase >= 2:
		_arm_vertical_rock(target_x + inward * 390.0, BossRock.RockSize.MEDIUM,
			BossRock.MotionKind.ERUPT, 0.36, stomp_number + 3)


func _player_target_x() -> float:
	var target_x := (BOSS_LEFT + BOSS_RIGHT) * 0.5
	if player != null and is_instance_valid(player):
		target_x = to_local(player.global_position).x
	# The primary warning follows the player all the way to either room wall.
	return clampf(target_x, ROOM_LEFT + 35.0, ROOM_RIGHT - 35.0)


func _inward_direction(target_x: float) -> float:
	return 1.0 if target_x < (BOSS_LEFT + BOSS_RIGHT) * 0.5 else -1.0


func _fragment_positions(target_x: float, spacing: float) -> Array[float]:
	var left_edge := ROOM_LEFT + 35.0
	var right_edge := ROOM_RIGHT - 35.0
	if target_x - spacing < left_edge:
		return [target_x + spacing, target_x + spacing * 2.0]
	if target_x + spacing > right_edge:
		return [target_x - spacing, target_x - spacing * 2.0]
	return [target_x - spacing, target_x + spacing]


func _arm_vertical_rock(local_x: float, size: int, movement: int,
		launch_delay: float, variant: int) -> void:
	var rock := ROCK_SCENE.instantiate() as BossRock
	hazards.add_child(rock)
	var bounded_x := clampf(local_x, ROOM_LEFT + 35.0, ROOM_RIGHT - 35.0)
	rock.configure(to_global(Vector2(bounded_x, FLOOR_Y)), size, movement,
		launch_delay, variant)
	if player != null and is_instance_valid(player):
		var tracking_ratio := 0.52 if _warning_phase == 1 else 0.58 if _warning_phase == 2 else 0.62
		var prediction := 0.13 if _warning_phase == 1 else 0.18 if _warning_phase == 2 else 0.22
		var initial_player_x := to_local(player.global_position).x
		rock.configure_tracking(player, bounded_x - initial_player_x,
			to_global(Vector2(ROOM_LEFT + 35.0, 0.0)).x,
			to_global(Vector2(ROOM_RIGHT - 35.0, 0.0)).x,
			_warning_windup_duration() * tracking_ratio, prediction)
	_pending_rocks.append(rock)


func _warning_windup_duration() -> float:
	match _warning_phase:
		2: return 0.66
		3: return 0.56
		_: return 0.78


func _spawn_shockwaves(_stomp_number: int, phase: int, powerful: bool) -> void:
	var floor_global_y := to_global(Vector2(0.0, FLOOR_Y)).y
	var room_left_global := to_global(Vector2(ROOM_LEFT, 0.0)).x
	var room_right_global := to_global(Vector2(ROOM_RIGHT, 0.0)).x
	var speed := 620.0 if phase == 1 else 720.0 if phase == 2 else 810.0
	var toward_player := -1.0
	if player != null and is_instance_valid(player):
		toward_player = signf(player.global_position.x - boss.global_position.x)
		if is_zero_approx(toward_player):
			toward_player = -1.0
	_spawn_shockwave(Vector2(boss.global_position.x, floor_global_y - 9.0),
		toward_player, speed, room_left_global, room_right_global)
	# Later phases require a jump even if the player crosses behind the boss.
	# The fifth-pattern heavy stomp also earns a two-sided wave in phase one.
	if phase >= 2 or powerful:
		_spawn_shockwave(Vector2(boss.global_position.x, floor_global_y - 9.0),
			-toward_player, speed, room_left_global, room_right_global)


func _spawn_shockwave(at: Vector2, direction: float, speed: float,
		left_bound: float, right_bound: float) -> void:
	var wave := SHOCKWAVE_SCENE.instantiate() as BossShockwave
	hazards.add_child(wave)
	wave.configure(at, direction, speed, left_bound, right_bound)


func _should_call_reinforcements(stomp_number: int) -> bool:
	if stomp_number < 3 or (stomp_number - 3) % 4 != 0:
		return false
	if _reinforcement_wave >= MAX_REINFORCEMENT_WAVES:
		return false
	if arena_adds.get_child_count() > 0:
		return false
	return not _victory


func _spawn_reinforcements() -> void:
	_reinforcement_wave += 1
	var spawn_x := 4050.0 if _reinforcement_wave % 2 == 1 else 2750.0
	_spawn_add(GUARD_SCENE, Vector2(spawn_x, FLOOR_Y))


func _spawn_add(scene: PackedScene, local_spawn: Vector2) -> void:
	var unit := scene.instantiate() as Enemy
	# Configure the local transform before add_child(), because Guard records its
	# global patrol origin in _ready(). Moving it afterward makes that origin the
	# ArenaAdds node at (0, 0), so it marches left trying to return outside.
	unit.position = local_spawn
	unit.detection_range = 760.0
	if unit is Guard:
		unit.patrol_distance = 150.0
		unit.territory = 1450.0
	arena_adds.add_child(unit)


func _on_boss_defeated() -> void:
	if _victory:
		return
	_victory = true
	_stop_all_danger()
	if _screen_fx != null and is_instance_valid(_screen_fx):
		_screen_fx.set_vignette(0.0, 0.6)
	MusicManager.stop_music(3.0)
	_finish_encounter.call_deferred()


func _stop_all_danger() -> void:
	_clear_pending_rocks()
	for rock in hazards.get_children():
		if rock is BossRock:
			rock.stop()
		else:
			rock.queue_free()
	for unit in arena_adds.get_children():
		unit.queue_free()
	# Clear any projectile already present so victory always stops all danger.
	var level := get_tree().current_scene
	if level != null:
		for projectile in level.find_children("*", "Bullet", true, false):
			projectile.queue_free()


func _clear_pending_rocks() -> void:
	for rock in _pending_rocks:
		if is_instance_valid(rock):
			rock.queue_free()
	_pending_rocks.clear()


func _hide_staircase() -> void:
	staircase.hide()
	for step in staircase.get_children():
		if step is StaticBody2D:
			step.collision_layer = 0
			step.collision_mask = 0
			step.modulate.a = 0.0


func _finish_encounter() -> void:
	await _reveal_staircase()
	_run_victory_sequence()


func _reveal_staircase() -> void:
	staircase.show()
	for step in staircase.get_children():
		if not step is StaticBody2D:
			continue
		var resting_position: Vector2 = step.position
		step.position.y += 20.0
		step.modulate.a = 0.0
		step.collision_layer = 1
		var reveal := create_tween().set_parallel(true)
		reveal.tween_property(step, ^"position", resting_position, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		reveal.tween_property(step, ^"modulate:a", 1.0, 0.12)
		await reveal.finished
		# Each step lands with a puff of dust and a small jolt, so the stairs
		# arrive out of the same rock the titan was made of.
		BossVfx.dust_burst(self, step.global_position, 0.7, true, 9)
		if _camera_rig != null and is_instance_valid(_camera_rig):
			_camera_rig.add_trauma(0.2)


func _run_victory_sequence() -> void:
	if player == null or not is_instance_valid(player):
		return
	player.powers.cancel()
	player.clear_combat_effects()
	player.velocity = Vector2.ZERO
	player.facing = 1
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := player.get_node_or_null(^"Camera2D") as Camera2D
	if camera != null:
		# The player must ignore input, but its child camera still has to process
		# while the tween carries the player up to the sister.
		camera.process_mode = Node.PROCESS_MODE_ALWAYS
		camera.position_smoothing_enabled = true
	var player_sprite := player.get_node(^"Sprite") as AnimatedSprite2D
	player_sprite.process_mode = Node.PROCESS_MODE_ALWAYS
	player_sprite.flip_h = false
	player_sprite.play(&"run")
	await _move_player_to(Vector2(4100, FLOOR_Y), 330.0)

	var jump_route := [
		Vector2(4230, 260),
		Vector2(4370, 130),
		Vector2(4550, -60),
	]
	for point in jump_route:
		await _jump_player_to(point, player_sprite)
	player_sprite.play(&"idle")
	await get_tree().create_timer(0.35).timeout
	var ending := create_tween()
	ending.tween_property(fade, ^"color:a", 1.0, 1.25).set_trans(Tween.TRANS_SINE)
	await ending.finished
	var level := get_parent().get_parent() as Level
	if level != null:
		level.complete()


func _move_player_to(local_destination: Vector2, speed: float) -> void:
	var destination := to_global(local_destination)
	var duration := maxf(player.global_position.distance_to(destination) / speed, 0.16)
	var movement := create_tween()
	movement.tween_property(player, ^"global_position", destination, duration)
	await movement.finished


func _jump_player_to(local_destination: Vector2, player_sprite: AnimatedSprite2D) -> void:
	var start := player.global_position
	var destination := to_global(local_destination)
	var horizontal_distance := absf(destination.x - start.x)
	var duration := maxf(horizontal_distance / 280.0, 0.48)
	var arc_height := maxf(68.0, absf(destination.y - start.y) * 0.45 + 42.0)
	player_sprite.play(&"jump")
	var jump_audio := player.get_node_or_null(^"JumpAudio") as AudioStreamPlayer2D
	if jump_audio != null:
		jump_audio.process_mode = Node.PROCESS_MODE_ALWAYS
		jump_audio.play()
	var jump := create_tween()
	jump.tween_method(
		func(progress: float) -> void:
			var position_on_line := start.lerp(destination, progress)
			position_on_line.y -= sin(progress * PI) * arc_height
			player.global_position = position_on_line,
		0.0,
		1.0,
		duration
	)
	await jump.finished
	player.global_position = destination
	player_sprite.play(&"land")
	await get_tree().create_timer(0.08).timeout
