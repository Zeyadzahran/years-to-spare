extends Node
## Runtime coverage for boss-room loading and environmental respawn rules.

const LEVEL_SCENE := preload("res://src/levels/level_01/level_01.tscn")
const PLAYER_SCENE := preload("res://src/actors/player/player.tscn")
const LEVEL_START := Vector2(337, 606)
const TEST_CHECKPOINT := Vector2(9198, 604)
const SPIKE_SCENES := [
	preload("res://src/levels/level_01/hazards/spike_strip_small.tscn"),
	preload("res://src/levels/level_01/hazards/spike_strip_large.tscn"),
	preload("res://src/levels/level_01/hazards/wall_trap.tscn"),
	preload("res://src/levels/level_01/hazards/ceiling_obstacle.tscn"),
]

var _death_announcements := 0


func _ready() -> void:
	GameState.clear_run_progress()
	await _verify_direct_boss_room_load()
	await _verify_normal_damage_and_checkpoint()
	await _verify_spikes_restart_at_start()
	await _verify_void_restarts_at_start()
	GameState.clear_run_progress()
	print("BOSS_GATE_AND_RESPAWN_RULES_VERIFIED")
	get_tree().quit()


func _verify_direct_boss_room_load() -> void:
	var level := await _fresh_level()
	var world := level.get_node(^"World")
	var player := level.get_node(^"Entities/Player") as Player
	var gate := level.get_node(^"World/SalvageYard/Gates/BossGate") as BossGate
	assert(player != null)
	assert(gate != null)
	assert(not world.has_node(^"BossRoom"))

	player.age.set_to(33.0)
	var health_before := player.health.current
	gate._on_body_entered(player)
	await get_tree().create_timer(1.35).timeout

	assert(world.has_node(^"BossRoom"))
	var room := world.get_node(^"BossRoom")
	var spawn := room.get_node(^"PlayerSpawn") as Marker2D
	var warden := room.get_node(^"Warden") as Warden
	var sister := room.get_node(^"TrappedSister") as Sprite2D
	var arena_terrain := room.get_node(^"Terrain") as TileMapLayer
	print("BOSS_GATE_POSITION actual=%s spawn=%s" % [player.global_position, spawn.global_position])
	assert(player.global_position.distance_to(spawn.global_position) < 4.0)
	assert(player.is_on_floor())
	assert(player.facing == 1)
	assert(is_equal_approx(player.age.age, 33.0))
	assert(is_equal_approx(player.health.current, health_before))
	assert(player.process_mode == Node.PROCESS_MODE_INHERIT)
	assert(is_zero_approx(gate.get_node(^"Transition/Fade").color.a))
	assert(arena_terrain.tile_set == load("res://src/levels/level_01/terrain_tileset.tres"))
	assert(arena_terrain.get_used_cells().size() == 118)
	assert(warden.target == player)
	assert(warden.global_position.distance_to(player.global_position) <= warden.detection_range)
	assert(absf(sister.global_position.x - player.global_position.x) < 450.0)
	assert((player.get_node(^"Camera2D") as Camera2D).zoom == Vector2(1.25, 1.25))

	level.queue_free()
	await get_tree().process_frame


func _verify_normal_damage_and_checkpoint() -> void:
	var player := await _fresh_player()
	var source := Node2D.new()
	add_child(source)
	var health_before := player.health.current
	player.health.take_damage(34.0, source)
	assert(player.health.is_alive())
	assert(is_equal_approx(player.health.current, health_before - 34.0))
	assert(player.states.current_name == &"Hurt")
	assert(not GameState.respawn_at_level_start_once)
	player.queue_free()
	source.queue_free()
	await get_tree().process_frame

	GameState.set_checkpoint(&"normal_damage_checkpoint", TEST_CHECKPOINT, 27.0)
	var level := await _fresh_level()
	var respawned := level.get_node(^"Entities/Player") as Player
	print("NORMAL_RESPAWN actual=%s checkpoint=%s" % [respawned.global_position, TEST_CHECKPOINT])
	assert(respawned.global_position.distance_to(TEST_CHECKPOINT) < 5.0)
	level.queue_free()
	await get_tree().process_frame


func _verify_spikes_restart_at_start() -> void:
	EventBus.player_died.connect(_on_player_died)
	var before := _death_announcements
	for packed_spike: PackedScene in SPIKE_SCENES:
		var player := await _fresh_player()
		var spike := packed_spike.instantiate() as Hazard
		add_child(spike)
		await get_tree().process_frame
		assert(spike.instant_death)
		spike._hurt(player)
		assert(not player.health.is_alive())
		assert(player.states.current_name == &"Dead")
		player.queue_free()
		spike.queue_free()
		await get_tree().process_frame
	assert(GameState.respawn_at_level_start_once)
	EventBus.player_died.disconnect(_on_player_died)

	var level := await _fresh_level()
	var respawned := level.get_node(^"Entities/Player") as Player
	print("SPIKE_RESPAWN actual=%s start=%s" % [respawned.global_position, LEVEL_START])
	assert(respawned.global_position.distance_to(LEVEL_START) < 7.0)
	assert(GameState.has_checkpoint(&"phase_1"))
	assert(not GameState.respawn_at_level_start_once)
	level.queue_free()
	await get_tree().process_frame
	assert(_death_announcements == before)


func _verify_void_restarts_at_start() -> void:
	var player := await _fresh_player()
	player.global_position.y = Player.VOID_DEATH_Y + 1.0
	await get_tree().physics_frame
	assert(not player.health.is_alive())
	assert(player.states.current_name == &"Dead")
	assert(GameState.respawn_at_level_start_once)
	player.queue_free()
	await get_tree().process_frame

	var level := await _fresh_level()
	var respawned := level.get_node(^"Entities/Player") as Player
	print("VOID_RESPAWN actual=%s start=%s" % [respawned.global_position, LEVEL_START])
	assert(respawned.global_position.distance_to(LEVEL_START) < 7.0)
	assert(GameState.has_checkpoint(&"phase_1"))
	assert(not GameState.respawn_at_level_start_once)
	level.queue_free()
	await get_tree().process_frame


func _fresh_level() -> Level:
	var level := LEVEL_SCENE.instantiate() as Level
	add_child(level)
	await get_tree().process_frame
	await get_tree().physics_frame
	return level


func _fresh_player() -> Player:
	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	await get_tree().process_frame
	await get_tree().physics_frame
	return player


func _on_player_died(_of_old_age: bool) -> void:
	_death_announcements += 1
