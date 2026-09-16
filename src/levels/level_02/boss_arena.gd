extends Node2D
## Level 2's final boss room.
##
## The Business Man has three health thirds. At 2/3 and 1/3 remaining he
## disappears, a portal opens at the room entrance, and a random 3-5 Guard /
## Gunner reinforcement wave comes
## through it. The boss returns after that wave is cleared. At zero health his
## red death explosion finishes the encounter.

const ROOM_LEFT := 0.0
const ROOM_RIGHT := 1600.0
const ROOM_TOP := -160.0
const ROOM_BOTTOM := 920.0
const GUARD_SCENE := preload("res://src/actors/enemy/guard.tscn")
const GUNNER_SCENE := preload("res://src/actors/enemy/gunner.tscn")
const PLATFORM_TELEPORT_COOLDOWN := 4.0

var player: Player
var _started := false
var _defeated := false
var _intermission := false
var _phase_breaks := 0
var _reinforcements: Array[Enemy] = []
var _platform_teleport_cooldown := 0.0

@onready var boss: BusinessBoss = $BusinessBoss
@onready var boss_bar: ProgressBar = $BossUI/Panel/BossHealth
@onready var boss_ui: CanvasLayer = $BossUI
@onready var reinforcement_gate: ReinforcementGate = $ReinforcementGate

func prepare_gate_entry(entry_player: Player) -> void:
	player = entry_player
	_configure_camera()
	_start_encounter()

func _ready() -> void:
	boss_ui.hide()
	reinforcement_gate.hide()
	boss.health.changed.connect(_on_boss_health_changed)
	boss.defeated.connect(_on_boss_defeated)
	boss_bar.max_value = boss.health.max_health
	boss_bar.value = boss.health.current

func _start_encounter() -> void:
	if _started or _defeated or player == null:
		return
	_started = true
	boss.target = player
	boss_ui.show()
	boss_bar.max_value = boss.health.max_health
	boss_bar.value = boss.health.current


func _physics_process(delta: float) -> void:
	if _platform_teleport_cooldown > 0.0:
		_platform_teleport_cooldown = maxf(_platform_teleport_cooldown - delta, 0.0)
	if not _started or _intermission or _defeated or _platform_teleport_cooldown > 0.0:
		return
	var platform := _platform_under_player()
	if platform == null:
		return
	_platform_teleport_cooldown = PLATFORM_TELEPORT_COOLDOWN
	var half_width := platform.width_tiles * 32.0
	var side := -1.0 if player.global_position.x >= platform.global_position.x else 1.0
	# Keep the boss on the deck, at its far side, rather than overlapping the
	# player who triggered the teleport.
	var destination := platform.global_position + Vector2(side * maxf(half_width - 44.0, 0.0), 0.0)
	boss.teleport_to_platform(destination)


func _platform_under_player() -> MovingIndustrialPlatform:
	if player == null or not is_instance_valid(player):
		return null
	for child in $Platforms.get_children():
		var platform := child as MovingIndustrialPlatform
		if platform == null:
			continue
		var half_width := platform.width_tiles * 32.0
		var on_platform := absf(player.global_position.x - platform.global_position.x) <= half_width
		on_platform = on_platform and absf(player.global_position.y - platform.global_position.y) <= 48.0
		if on_platform:
			return platform
	return null

func _configure_camera() -> void:
	if player == null:
		return
	var camera := player.get_node_or_null(^"Camera2D") as Camera2D
	if camera == null:
		return
	camera.limit_left = roundi(global_position.x + ROOM_LEFT)
	camera.limit_right = roundi(global_position.x + ROOM_RIGHT)
	camera.limit_top = roundi(global_position.y + ROOM_TOP)
	camera.limit_bottom = roundi(global_position.y + ROOM_BOTTOM)
	camera.limit_smoothed = false

func _on_boss_health_changed(current: float, maximum: float) -> void:
	if boss_bar == null:
		return
	boss_bar.max_value = maximum
	boss_bar.value = current
	# There are exactly two breaks: at two-thirds and one-third health. Once
	# both waves have been cleared, the remaining final third must stay playable
	# through to the boss's actual death instead of reopening the gate on every
	# subsequent hit.
	if not _started or _intermission or _defeated or current <= 0.0 or _phase_breaks >= 2:
		return

	# 1200 -> 800 -> 400 -> 0. The first two thresholds are reinforcement
	# breaks; reaching zero is the actual boss death.
	var next_threshold := _boss_health_for_break(_phase_breaks)
	if current <= next_threshold:
		_phase_breaks += 1
		_start_reinforcement_break()

func _boss_health_for_break(completed_breaks: int) -> float:
	return boss.health.max_health * (2.0 / 3.0) if completed_breaks == 0 else boss.health.max_health * (1.0 / 3.0)

func _start_reinforcement_break() -> void:
	if _intermission or _defeated or boss.state == &"Dead":
		return
	_intermission = true
	_start_reinforcement_sequence()

func _start_reinforcement_sequence() -> void:
	await boss.begin_intermission()
	if _defeated or not is_instance_valid(boss):
		return

	reinforcement_gate.show()
	await reinforcement_gate.open()
	if _defeated:
		return

	var count := randi_range(3, 5)
	_reinforcements.clear()
	var offsets := [-110.0, -55.0, 0.0, 55.0, 110.0]
	for i in range(count):
		_spawn_reinforcement(i, offsets[i])
		await get_tree().create_timer(0.18).timeout

	await _wait_for_reinforcements()
	if _defeated:
		return

	await reinforcement_gate.close()
	boss.resume_after_intermission()
	_intermission = false

func _spawn_reinforcement(index: int, x_offset: float) -> void:
	var enemy := (GUARD_SCENE if index % 2 == 0 else GUNNER_SCENE).instantiate() as Enemy
	$Reinforcements.add_child(enemy)
	_reinforcements.append(enemy)
	enemy.name = ("ReinforcementGuard%d" if enemy is Guard else "ReinforcementGunner%d") % (index + 1)
	enemy.global_position = reinforcement_gate.global_position
	enemy.target = player
	enemy.velocity = Vector2.ZERO
	enemy.scale = Vector2(0.15, 0.15)
	enemy.collision_layer = 0
	enemy.collision_mask = 0
	if enemy is Guard:
		var guard := enemy as Guard
		guard.patrol_origin_x = guard.global_position.x
		guard.territory = ROOM_RIGHT - ROOM_LEFT

	# The gate is on the far right. Reinforcements cross the player's position
	# before they become solid, so they emerge into the arena instead of bunching
	# behind its frame.
	var exit_direction := signf(player.global_position.x - reinforcement_gate.global_position.x)
	if is_zero_approx(exit_direction):
		exit_direction = -1.0
	var destination := Vector2(player.global_position.x + exit_direction * 120.0 + x_offset, reinforcement_gate.global_position.y)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(enemy, ^"global_position", destination, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(enemy, ^"scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(func():
		if is_instance_valid(enemy):
			enemy.collision_layer = 4
			enemy.collision_mask = 1
	)

func _wait_for_reinforcements() -> void:
	while true:
		var living := 0
		for enemy in _reinforcements:
			if is_instance_valid(enemy) and enemy.has_node("Health"):
				var hp := enemy.get_node("Health") as HealthComponent
				if hp != null and hp.is_alive():
					living += 1
		if living == 0:
			return
		await get_tree().create_timer(0.15).timeout

func _on_boss_defeated() -> void:
	if _defeated:
		return
	_defeated = true
	_intermission = false
	boss_ui.show()
	boss_bar.value = 0.0
	if is_instance_valid(reinforcement_gate):
		reinforcement_gate.hide()

	await get_tree().create_timer(1.15).timeout
	var level := get_parent().get_parent() as Level
	if level != null:
		level.complete()
	if player != null and is_instance_valid(player):
		player.velocity = Vector2.ZERO
		player.process_mode = Node.PROCESS_MODE_DISABLED

	var result := boss_ui.get_node_or_null(^"Panel/Result") as Label
	if result != null:
		result.show()
