extends Control

@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value: Label = %VolumeValue
@onready var fullscreen_check: CheckButton = %FullscreenCheck
@onready var back_button: Button = %BackButton
@onready var main_menu_button: Button = %MainMenuButton
@onready var quit_button: Button = %QuitButton

const MAIN_MENU_SCENE := "res://src/ui/main_menu/main_menu.tscn"

## Set by whatever opens this over a running level (see src/ui/hud.gd): closing
## frees the panel instead of leaving for the main menu.
var overlay := false

func _ready():
	if overlay:
		# Let the level show through instead of the menu artwork.
		$Background.hide()
	else:
		# Back already leads to the menu when this is its own scene.
		main_menu_button.hide()
	volume_slider.value = SettingsManager.volume
	fullscreen_check.button_pressed = SettingsManager.fullscreen
	_update_volume_label(SettingsManager.volume)
	_update_fullscreen_label(SettingsManager.fullscreen)
	back_button.grab_focus()

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_on_back_button_pressed()

func _on_back_button_pressed():
	if overlay:
		queue_free()
		return
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_main_menu_button_pressed():
	# The level is paused while this sits over it; the menu needs it running.
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_quit_button_pressed():
	get_tree().quit()

func _on_volume_slider_value_changed(value):
	SettingsManager.volume = value
	SettingsManager.apply_volume()
	_update_volume_label(value)
	SettingsManager.save_settings()

func _on_fullscreen_check_toggled(toggled_on):
	SettingsManager.fullscreen = toggled_on
	SettingsManager.apply_fullscreen()
	_update_fullscreen_label(toggled_on)
	SettingsManager.save_settings()

func _update_volume_label(value):
	volume_value.text = str(int(round(value)))

func _update_fullscreen_label(enabled: bool):
	fullscreen_check.text = "ON" if enabled else "OFF"
