extends Control

var menu_music = preload("res://assets/music/The_Weight_of_November.mp3")

func _on_play_button_pressed():
	# The checkpoint outlives a death on purpose, so it also outlives a trip
	# back to the menu. PLAY is the one place that means a new run.
	GameState.clear_checkpoint()
	get_tree().change_scene_to_file(
		"res://src/levels/intro.tscn"
	)


func _on_options_button_pressed():
	get_tree().change_scene_to_file("res://scenes/options.tscn")


func _on_quit_button_pressed():
	get_tree().quit()

func _ready():
	MusicManager.play_music(menu_music, 1.5)
