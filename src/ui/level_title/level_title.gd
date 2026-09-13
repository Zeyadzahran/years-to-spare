extends Node2D
## Text and layout are authored in each title scene; only the destination varies.

@export_file("*.tscn") var next_scene: String

@onready var background = $UI/Background
@onready var level_intro = $UI/LevelIntro
@onready var level_number = $UI/LevelIntro/LevelTitle
@onready var level_name = $UI/LevelIntro/LevelName
@onready var subtitle = $UI/LevelIntro/Subtitle
@onready var post_title_black_screen: ColorRect = get_node_or_null("UI/PostTitleBlackScreen")
@onready var post_title_voice_over: AudioStreamPlayer = get_node_or_null("PostTitleVoiceOver")
@onready var post_title_subtitle: Label = get_node_or_null("UI/PostTitleSubtitle")

const POST_TITLE_SUBTITLES = [
	{"time": 0.0, "text": "They call it the City of Time."},
	{"time": 3.29, "text": "Built on a clock no one asked to wind."},
	{"time": 6.70, "text": "Every year in this place belongs to someone who never agreed to give it."},
	{"time": 11.95, "text": "City of Time..."},
	{"time": 13.54, "text": "huh."},
	{"time": 15.32, "text": "City of Thieves."},
]


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

	if post_title_black_screen != null and post_title_voice_over != null and post_title_subtitle != null:
		post_title_black_screen.visible = true
		post_title_subtitle.visible = true
		post_title_voice_over.play()
		await play_post_title_subtitles()
		await post_title_voice_over.finished
		post_title_subtitle.visible = false

	start_next_scene()


func play_post_title_subtitles() -> void:
	post_title_subtitle.text = POST_TITLE_SUBTITLES[0].text
	for index in range(1, POST_TITLE_SUBTITLES.size()):
		var delay = POST_TITLE_SUBTITLES[index].time - POST_TITLE_SUBTITLES[index - 1].time
		await get_tree().create_timer(delay).timeout
		post_title_subtitle.text = POST_TITLE_SUBTITLES[index].text


func start_next_scene():
	get_tree().change_scene_to_file(next_scene)
