extends Node

var volume: float = 80.0
var fullscreen: bool = false

const SETTINGS_FILE = "user://settings.cfg"


func _ready():
	load_settings()


func save_settings():
	var config = ConfigFile.new()

	config.set_value("audio", "volume", volume)
	config.set_value("display", "fullscreen", fullscreen)

	config.save(SETTINGS_FILE)


func load_settings():
	var config = ConfigFile.new()

	if config.load(SETTINGS_FILE) == OK:
		volume = config.get_value("audio", "volume", 80.0)
		fullscreen = config.get_value("display", "fullscreen", false)
