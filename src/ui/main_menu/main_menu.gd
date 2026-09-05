extends Control

var menu_music = preload("res://assets/music/The_Weight_of_November.mp3")

func _on_play_button_pressed():
	# The checkpoint, the years already spent and the bodies all outlive a death
	# on purpose, so they also outlive a trip back to the menu. PLAY is the one
	# place that means a new run.
	GameState.clear_run_progress()
	get_tree().change_scene_to_file(
		"res://src/cinematics/intro/intro.tscn"
	)


func _on_options_button_pressed():
	get_tree().change_scene_to_file("res://src/ui/options/options.tscn")


func _on_quit_button_pressed():
	get_tree().quit()

func _ready():
	MusicManager.play_music(menu_music, 1.5)
