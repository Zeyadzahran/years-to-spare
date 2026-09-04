extends Node

var volume: float = 80.0
## Matches `window/size/mode` in project.godot, which starts the game fullscreen.
var fullscreen: bool = true

const SETTINGS_FILE = "user://settings.cfg"


func _ready():
	load_settings()
	apply_volume()
	apply_fullscreen()


## Pushes `volume` (0-100) onto the master bus. Call after changing it.
func apply_volume():
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(volume / 100.0)
	)


## Puts the window into the mode `fullscreen` asks for. Call after changing it.
func apply_fullscreen():
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED
	)


func save_settings():
	var config = ConfigFile.new()

	config.set_value("audio", "volume", volume)
	config.set_value("display", "fullscreen", fullscreen)

	config.save(SETTINGS_FILE)


func load_settings():
	var config = ConfigFile.new()

	if config.load(SETTINGS_FILE) == OK:
		volume = config.get_value("audio", "volume", 80.0)
		fullscreen = config.get_value("display", "fullscreen", true)
