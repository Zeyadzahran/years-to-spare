extends Node

var volume: float = 80.0
## Category sliders only attenuate the authored mix: 100% adds no gain.
var music_volume: float = 100.0
var environment_volume: float = 100.0
var sfx_volume: float = 100.0
## Matches `window/size/mode` in project.godot, which starts the game fullscreen.
var fullscreen: bool = true
var settings_path := "user://settings.cfg"
const MUSIC_BUS := &"Music"
const ENVIRONMENT_BUS := &"Environment"
const SFX_BUS := &"SFX"


func _ready():
	load_settings()
	apply_audio()
	apply_fullscreen()


## Buses preserve per-sound tuning and fades. Muting leaves playback running.
func apply_audio() -> void:
	_set_bus_volume(&"Master", volume)
	_set_bus_volume(MUSIC_BUS, music_volume)
	_set_bus_volume(ENVIRONMENT_BUS, environment_volume)
	_set_bus_volume(SFX_BUS, sfx_volume)


func _set_bus_volume(bus: StringName, percent: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	var gain := clampf(percent / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(index, is_zero_approx(gain))
	AudioServer.set_bus_volume_db(index, linear_to_db(gain) if gain > 0.0 else 0.0)


## Puts the window into the mode `fullscreen` asks for. Call after changing it.
func apply_fullscreen():
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED
	)


## Esc drops the window out of fullscreen, the way every other fullscreen thing
## on the machine behaves. The game now *starts* fullscreen, so without this the
## only way back out is to find it in the options panel - and remembering the
## choice matters as much as making it, or the next launch traps you again.
##
## Returns whether it actually did anything, so a caller that owns Esc for
## something else can let this have first refusal and then carry on.
func leave_fullscreen() -> bool:
	if not fullscreen:
		return false
	fullscreen = false
	apply_fullscreen()
	save_settings()
	return true


## Scenes with nothing else bound to Esc - the menu, the intro - get the same
## behaviour for free. Autoloads sit above the current scene in the tree and
## unhandled input runs bottom-up, so anything in the scene that wants Esc for
## itself still sees it first.
func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		if leave_fullscreen():
			get_viewport().set_input_as_handled()


func save_settings():
	var config = ConfigFile.new()

	config.set_value("audio", "volume", volume)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "environment_volume", environment_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("display", "fullscreen", fullscreen)

	config.save(settings_path)


func load_settings():
	var config = ConfigFile.new()

	config.load(settings_path)
	volume = clampf(config.get_value("audio", "volume", 80.0), 0.0, 100.0)
	# Preserve the old music switch when upgrading an existing settings file.
	var old_music_volume := 100.0 if config.get_value("audio", "music", true) else 0.0
	music_volume = clampf(config.get_value("audio", "music_volume", old_music_volume), 0.0, 100.0)
	environment_volume = clampf(config.get_value("audio", "environment_volume", 100.0), 0.0, 100.0)
	sfx_volume = clampf(config.get_value("audio", "sfx_volume", 100.0), 0.0, 100.0)
	fullscreen = config.get_value("display", "fullscreen", true)
