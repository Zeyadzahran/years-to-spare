extends Node

var volume: float = 80.0
## Matches `window/size/mode` in project.godot, which starts the game fullscreen.
var fullscreen: bool = true
## Music only; sound effects and ambience stay on the master bus. Off mutes
## the bus rather than stopping the player, so the track is still where it
## would have been when it comes back on.
var music: bool = true

const SETTINGS_FILE = "user://settings.cfg"
## Made here at startup rather than in the bus layout resource, so the layout
## stays whatever the editor saved and nothing else has to know the bus exists.
const MUSIC_BUS := &"Music"


func _ready():
	load_settings()
	apply_volume()
	apply_music()
	apply_fullscreen()


## Pushes `volume` (0-100) onto the master bus. Call after changing it.
func apply_volume():
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		linear_to_db(volume / 100.0)
	)


## Mutes or unmutes the music bus to match `music`. Call after changing it.
func apply_music():
	AudioServer.set_bus_mute(music_bus_index(), not music)


## The bus MusicManager plays through, created on first ask.
func music_bus_index() -> int:
	var index := AudioServer.get_bus_index(MUSIC_BUS)
	if index < 0:
		index = AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, MUSIC_BUS)
		AudioServer.set_bus_send(index, &"Master")
	return index


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
	config.set_value("audio", "music", music)
	config.set_value("display", "fullscreen", fullscreen)

	config.save(SETTINGS_FILE)


func load_settings():
	var config = ConfigFile.new()

	if config.load(SETTINGS_FILE) == OK:
		volume = config.get_value("audio", "volume", 80.0)
		music = config.get_value("audio", "music", true)
		fullscreen = config.get_value("display", "fullscreen", true)
