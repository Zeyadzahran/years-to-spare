extends Control

@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value: Label = %VolumeValue
@onready var music_slider: HSlider = %MusicSlider
@onready var music_value: Label = %MusicValue
@onready var environment_slider: HSlider = %EnvironmentSlider
@onready var environment_value: Label = %EnvironmentValue
@onready var sfx_slider: HSlider = %SfxSlider
@onready var sfx_value: Label = %SfxValue
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
	_init_volume_control(volume_slider, volume_value, SettingsManager.volume)
	_init_volume_control(music_slider, music_value, SettingsManager.music_volume)
	_init_volume_control(environment_slider, environment_value, SettingsManager.environment_volume)
	_init_volume_control(sfx_slider, sfx_value, SettingsManager.sfx_volume)
	fullscreen_check.set_pressed_no_signal(SettingsManager.fullscreen)
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

func _on_volume_slider_value_changed(value: float) -> void:
	SettingsManager.volume = value
	_save_volume(volume_value, value)

func _on_music_slider_value_changed(value: float) -> void:
	SettingsManager.music_volume = value
	_save_volume(music_value, value)

func _on_environment_slider_value_changed(value: float) -> void:
	SettingsManager.environment_volume = value
	_save_volume(environment_value, value)

func _on_sfx_slider_value_changed(value: float) -> void:
	SettingsManager.sfx_volume = value
	_save_volume(sfx_value, value)

func _save_volume(label: Label, value: float) -> void:
	label.text = "%d%%" % roundi(value)
	SettingsManager.apply_audio()
	SettingsManager.save_settings()

func _on_fullscreen_check_toggled(toggled_on):
	SettingsManager.fullscreen = toggled_on
	SettingsManager.apply_fullscreen()
	_update_fullscreen_label(toggled_on)
	SettingsManager.save_settings()

func _init_volume_control(slider: HSlider, label: Label, value: float) -> void:
	slider.set_value_no_signal(value)
	label.text = "%d%%" % roundi(value)

func _update_fullscreen_label(enabled: bool):
	fullscreen_check.text = "ON" if enabled else "OFF"
