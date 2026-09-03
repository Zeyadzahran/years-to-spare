extends Control

@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value: Label = %VolumeValue
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var back_button: Button = %BackButton

func _ready():
	volume_slider.value = SettingsManager.volume
	fullscreen_check.button_pressed = SettingsManager.fullscreen
	_update_volume_label(SettingsManager.volume)
	_update_fullscreen_label(SettingsManager.fullscreen)
	back_button.grab_focus()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		_on_back_button_pressed()

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://src/levels/main_menu.tscn")

func _on_volume_slider_value_changed(value):
	SettingsManager.volume = value
	var volume_db = linear_to_db(value / 100.0)
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index("Master"),
		volume_db
	)
	_update_volume_label(value)
	SettingsManager.save_settings()

func _on_fullscreen_check_toggled(toggled_on):
	SettingsManager.fullscreen = toggled_on
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	_update_fullscreen_label(toggled_on)
	SettingsManager.save_settings()

func _update_volume_label(value):
	volume_value.text = str(int(round(value)))

func _update_fullscreen_label(enabled: bool):
	fullscreen_check.text = "ON" if enabled else "OFF"
