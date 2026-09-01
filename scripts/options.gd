extends Control

@onready var volume_slider = $Settings/VolumeRow/VolumeSlider
@onready var fullscreen_check = $Settings/FullscreenRow/FullscreenCheck

func _ready():
	volume_slider.value = SettingsManager.volume
	fullscreen_check.button_pressed = SettingsManager.fullscreen

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://src/levels/main_menu.tscn")

func _on_volume_slider_value_changed(value):
	SettingsManager.volume = value
	var volume_db = linear_to_db(value / 100.0)
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		volume_db
	)
	SettingsManager.save_settings()

func _on_fullscreen_check_toggled(toggled_on):
	SettingsManager.fullscreen = toggled_on
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		
	SettingsManager.save_settings()	
