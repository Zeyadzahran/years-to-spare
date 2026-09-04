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
	config.set_value("display", "fullscreen", fullscreen)

	config.save(SETTINGS_FILE)


func load_settings():
	var config = ConfigFile.new()

	if config.load(SETTINGS_FILE) == OK:
		volume = config.get_value("audio", "volume", 80.0)
		fullscreen = config.get_value("display", "fullscreen", true)
