extends Node
## Checks the live options controls against the audio mixer and an isolated settings file.

const OPTIONS := preload("res://src/ui/options/options.tscn")
const CATEGORIES := [&"Music", &"Environment", &"SFX"]
var failures := 0
var routed_players := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func gain(bus: StringName) -> float:
	return AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(bus))

func muted(bus: StringName) -> bool:
	return AudioServer.is_bus_mute(AudioServer.get_bus_index(bus))

func check_routing(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer2D:
		routed_players += 1
		var expected := &"Environment" if node.get_parent().name == &"Ambience" else &"SFX"
		check(node.bus == expected, "%s should route to %s, got %s" % [node.name, expected, node.bus])
	for child in node.get_children():
		check_routing(child)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# No test interaction may write the player's real preferences.
	SettingsManager.settings_path = "/tmp/years-audio-settings-%d.cfg" % OS.get_process_id()
	SettingsManager.load_settings()
	SettingsManager.apply_audio()
	check(is_equal_approx(SettingsManager.volume, 80.0), "New installation changed the old master level")
	for bus in CATEGORIES:
		check(is_equal_approx(gain(bus), 1.0) and not muted(bus), "%s at 100%% changes the mix" % bus)
	var legacy := ConfigFile.new()
	legacy.set_value("audio", "volume", 37.0)
	legacy.set_value("audio", "music", false)
	legacy.set_value("display", "fullscreen", false)
	legacy.save(SettingsManager.settings_path)
	SettingsManager.load_settings()
	SettingsManager.apply_audio()
	check(is_equal_approx(gain(&"Master"), 0.37), "Old master setting was lost")
	check(muted(&"Music") and SettingsManager.music_volume == 0.0, "Old music-off setting was lost")
	check(gain(&"Environment") == 1.0 and gain(&"SFX") == 1.0, "Migration changed ambience or effects")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var panel := OPTIONS.instantiate()
	add_child(panel)
	await get_tree().process_frame
	check(panel.music_slider.value == 0.0 and panel.music_value.text == "0%", "UI did not load migrated settings")
	panel.music_slider.value = 25.0
	check(is_equal_approx(gain(&"Music"), 0.25) and not muted(&"Music"), "Music slider did not unmute and apply")
	check(gain(&"Environment") == 1.0 and gain(&"SFX") == 1.0, "Music slider changed other categories")
	panel.environment_slider.value = 40.0
	check(is_equal_approx(gain(&"Environment"), 0.4) and gain(&"SFX") == 1.0, "Environment slider is not independent")
	panel.sfx_slider.value = 60.0
	check(is_equal_approx(gain(&"SFX"), 0.6) and is_equal_approx(gain(&"Music"), 0.25), "Effects slider is not independent")
	check(is_equal_approx(gain(&"Master"), 0.37), "Category changes altered master gain")
	# Muting a category neither resets the music player nor alters authored gain.
	MusicManager.player.volume_db = -13.0
	panel.environment_slider.value = 0.0
	check(muted(&"Environment") and not muted(&"Music") and not muted(&"SFX"), "Environment mute affected another bus")
	panel.environment_slider.value = 40.0
	check(not muted(&"Environment"), "Environment did not unmute")
	panel.sfx_slider.value = 0.0
	check(muted(&"SFX") and not muted(&"Environment") and not muted(&"Music"), "Effects mute affected another bus")
	panel.sfx_slider.value = 60.0
	check(MusicManager.player.volume_db == -13.0 and MusicManager.player.bus == &"Music", "Category gain changed track tuning")
	# Reload from disk, then open the same panel as a paused-game overlay.
	SettingsManager.music_volume = 100.0
	SettingsManager.environment_volume = 100.0
	SettingsManager.sfx_volume = 100.0
	SettingsManager.load_settings()
	check(SettingsManager.music_volume == 25.0 and SettingsManager.environment_volume == 40.0 and SettingsManager.sfx_volume == 60.0,
		"Category settings did not survive a reload")
	panel.queue_free()
	await get_tree().process_frame
	panel = OPTIONS.instantiate()
	panel.overlay = true
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(panel)
	get_tree().paused = true
	await get_tree().process_frame
	check(panel.music_slider.value == 25.0 and panel.environment_slider.value == 40.0 and panel.sfx_slider.value == 60.0,
		"Pause options did not restore the three sliders")
	panel.music_slider.value = 100.0
	panel.environment_slider.value = 100.0
	panel.sfx_slider.value = 100.0
	panel.volume_slider.value = 80.0
	for bus in CATEGORIES:
		check(gain(bus) == 1.0 and not muted(bus), "%s did not restore original gain in pause menu" % bus)
	await get_tree().process_frame
	var rect: Rect2 = panel.get_node("Center/Panel").get_global_rect()
	check(get_viewport().get_visible_rect().encloses(rect), "Options panel extends beyond the screen")
	for slider in [panel.volume_slider, panel.music_slider, panel.environment_slider, panel.sfx_slider]:
		check(slider.size.x >= 150.0, "Volume slider is too narrow")
	get_tree().paused = false
	# Instantiate real levels/cinematics: nested sound players must be routed too.
	for path in ["res://src/levels/level_01/level_01.tscn", "res://src/levels/level_02/level_02.tscn",
			"res://src/cinematics/intro/intro.tscn", "res://src/cinematics/finale/finale.tscn"]:
		var scene := (load(path) as PackedScene).instantiate()
		check_routing(scene)
		scene.free()
	check(routed_players > 50, "Audio routing audit missed level instances")
	if "--capture" in OS.get_cmdline_user_args():
		panel.overlay = false
		panel.get_node("Background").show()
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/years-audio-options.png")
	DirAccess.remove_absolute(SettingsManager.settings_path)
	print("AUDIO_SETTINGS_VERIFIED failures=%d routed_players=%d" % [failures, routed_players])
	get_tree().quit(1 if failures else 0)
