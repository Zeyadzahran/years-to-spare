extends Node
## Level 2's rain, embers, ambience beds and music: what the day/night gateway
## does to them, what a reload restores, and that a stopped world holds them.
## Run with --headless --fixed-fps 60.

const MAP := preload("res://src/levels/level_02/level_02.tscn")

var failures := 0
var level: Level
var player: Player

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func fresh() -> void:
	TimeService.reset()
	if is_instance_valid(level):
		level.queue_free()
		await frames(2)
	level = MAP.instantiate()
	level.debug_spawn_path = NodePath()
	add_child(level)
	get_tree().current_scene = self
	player = level.get_node("Entities/Player")
	level.get_node("Enemies").process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("World/Hazards").process_mode = Node.PROCESS_MODE_DISABLED
	await frames(2)

func day_bed() -> AudioStreamPlayer: return level.get_node("Ambience/DayBed")
func night_bed() -> AudioStreamPlayer: return level.get_node("Ambience/NightBed")
func rain_bed() -> AudioStreamPlayer: return level.get_node("Ambience/RainBed")
func rain() -> CPUParticles2D: return level.get_node("Ambience/Rain")
func embers() -> CPUParticles2D: return level.get_node("Ambience/Embers")
func transition() -> Node: return level.get_node("DayNightTransition")

func _ready() -> void:
	await daylight_start()
	await gateway_crossfade()
	await reload_restores_night()
	await stop_time_holds()
	print("LEVEL_02_ATMOSPHERE_VERIFIED failures=%d" % failures)
	get_tree().quit(1 if failures else 0)

func daylight_start() -> void:
	GameState.clear_run_progress()
	await fresh()
	check(level.music != null and level.music.resource_path.ends_with("New_Factory.ogg"), "Level music not set")
	check(MusicManager.current_song == level.music, "Level music did not start")
	check(day_bed().playing and night_bed().playing and rain_bed().playing, "A bed is not playing")
	check(rain_bed().stream.loop and day_bed().stream.loop and night_bed().stream.loop, "A bed is not imported looping")
	check(is_equal_approx(rain_bed().volume_db, -3.0), "Rain bed not at its authored volume: %s" % rain_bed().volume_db)
	check(is_equal_approx(day_bed().volume_db, -3.0), "Day bed not at its authored volume: %s" % day_bed().volume_db)
	check(is_equal_approx(night_bed().volume_db, -40.0), "Night bed audible by day: %s" % night_bed().volume_db)
	check(rain().emitting and rain().amount == rain().density and rain().lifetime > 0.0, "Rain not running")
	check(embers().emitting and is_zero_approx(embers().modulate.a), "Embers visible by day")
	check(embers().material is CanvasItemMaterial and embers().material.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD, "Embers not additive")
	# The band sits above the view and spans it.
	var camera := player.get_node("Camera2D") as Camera2D
	var view := get_viewport().get_visible_rect().size / camera.zoom
	check(rain().global_position.y < camera.get_screen_center_position().y - view.y * 0.5, "Rain band not above the view")
	check(rain().emission_rect_extents.x >= view.x * 0.5, "Rain band narrower than the view")
	print("ATMOSPHERE daylight: music, beds, rain and hidden embers")

func gateway_crossfade() -> void:
	player.global_position = transition().get_node("Shape").global_position + Vector2(0, 0)
	await frames(4)
	check(GameState.night_active, "Gateway did not trigger night")
	await frames(30)
	check(night_bed().volume_db > -40.0 and night_bed().volume_db < -3.0, "Night bed not fading up mid-crossfade: %s" % night_bed().volume_db)
	check(day_bed().volume_db < -3.0 and day_bed().volume_db > -40.0, "Day bed not fading down mid-crossfade: %s" % day_bed().volume_db)
	await frames(150)
	check(is_equal_approx(night_bed().volume_db, -3.0), "Night bed did not reach its authored volume: %s" % night_bed().volume_db)
	check(is_equal_approx(day_bed().volume_db, -40.0), "Day bed did not go silent: %s" % day_bed().volume_db)
	check(is_equal_approx(embers().modulate.a, 1.0), "Embers did not fade in with the night")
	check(rain().emitting, "Rain stopped at night")
	check(is_equal_approx(rain_bed().volume_db, -3.0) and rain_bed().playing, "Rain sound faded with the daylight")
	transition().restore_daylight()
	check(is_equal_approx(day_bed().volume_db, -3.0) and is_equal_approx(night_bed().volume_db, -40.0), "Daylight did not restore the beds")
	check(is_zero_approx(embers().modulate.a), "Daylight did not put the embers away")
	print("ATMOSPHERE gateway crossfades beds and embers, daylight restores them")

func reload_restores_night() -> void:
	GameState.clear_run_progress()
	await fresh()
	player.global_position = transition().get_node("Shape").global_position
	await frames(4)
	GameState.set_checkpoint(&"L2Night", player.global_position + Vector2(200, 0), player.age.age, GameState.night_active)
	await fresh()
	check(is_equal_approx(night_bed().volume_db, -3.0) and is_equal_approx(day_bed().volume_db, -40.0), "Reload into night did not restore the night beds: day=%s night=%s" % [day_bed().volume_db, night_bed().volume_db])
	check(is_equal_approx(embers().modulate.a, 1.0), "Reload into night did not restore the embers")
	print("ATMOSPHERE checkpoint reload restores night sound and embers instantly")

func stop_time_holds() -> void:
	GameState.clear_run_progress()
	await fresh()
	player.global_position = Vector2(300, 640)
	await frames(60)
	check(is_equal_approx(rain().speed_scale, 1.0), "Rain not running at world speed")
	check(player.powers.try_cast(GameState.ABILITY_STOP), "Stop refused")
	await frames(60)
	check(TimeService.mode == TimeService.Mode.STOPPED, "World not stopped")
	check(is_zero_approx(rain().speed_scale) and is_zero_approx(embers().speed_scale), "Stopped world did not hold the weather")
	print("ATMOSPHERE a stopped world holds the rain and embers")
