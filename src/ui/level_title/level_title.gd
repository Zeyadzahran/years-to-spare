extends Node2D
## Text and layout are authored in each title scene; only the destination varies.

@export_file("*.tscn") var next_scene: String

@onready var background = $UI/Background
@onready var level_intro = $UI/LevelIntro
@onready var level_number = $UI/LevelIntro/LevelTitle
@onready var level_name = $UI/LevelIntro/LevelName
@onready var subtitle = $UI/LevelIntro/Subtitle


func _ready():

	# Start with a completely black screen.
	background.modulate.a = 1.0

	# Hide the level title text.
	level_number.modulate.a = 0.0
	level_name.modulate.a = 0.0
	subtitle.modulate.a = 0.0

	# Play the cinematic.
	play_level_intro()


func play_level_intro():
	# -----------------------------
	# FADE IN TITLE
	# -----------------------------

	var tween = create_tween()
	tween.set_parallel(true)

	# LEVEL NUMBER
	tween.tween_property(
		level_number,
		"modulate:a",
		1.0,
		0.8
	).set_delay(0.3)

	# LEVEL NAME
	tween.tween_property(
		level_name,
		"modulate:a",
		1.0,
		0.8
	).set_delay(0.8)

	# SUBTITLE
	tween.tween_property(
		subtitle,
		"modulate:a",
		1.0,
		0.8
	).set_delay(1.3)

	await tween.finished


	# -----------------------------
	# HOLD TITLE
	# -----------------------------

	await get_tree().create_timer(2.5).timeout


	# -----------------------------
	# FADE OUT TEXT
	# -----------------------------

	var fade_text = create_tween()
	fade_text.set_parallel(true)

	fade_text.tween_property(
		level_number,
		"modulate:a",
		0.0,
		0.8
	)

	fade_text.tween_property(
		level_name,
		"modulate:a",
		0.0,
		0.8
	)

	fade_text.tween_property(
		subtitle,
		"modulate:a",
		0.0,
		0.8
	)

	await fade_text.finished


	# -----------------------------
	# FADE OUT BACKGROUND
	# -----------------------------

	var fade_background = create_tween()

	fade_background.tween_property(
		background,
		"modulate:a",
		0.0,
		1.2
	)

	await fade_background.finished


	# -----------------------------
	# START GAMEPLAY
	# -----------------------------

	level_intro.visible = false
	background.visible = false

	start_next_scene()


func start_next_scene():
	get_tree().change_scene_to_file(next_scene)
