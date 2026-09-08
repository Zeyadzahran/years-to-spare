extends Control

@onready var logo = $LogoImage


func _ready():
	logo.modulate.a = 0.0

	var tween = create_tween()

	# Fade in
	tween.tween_property(
		logo,
		"modulate:a",
		1.0,
		1.5
	)

	# Stay on screen
	tween.tween_interval(2.0)

	# Fade out
	tween.tween_property(
		logo,
		"modulate:a",
		0.0,
		1.5
	)

	await tween.finished

	# Go to main menu
	get_tree().change_scene_to_file(
		"res://src/ui/main_menu/main_menu.tscn"
	)
