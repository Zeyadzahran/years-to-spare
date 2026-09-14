extends Control

var skip_intro := false
var intro_music = preload("res://assets/music/A_Bridge_to_Yesterday.mp3")

var images = [
	preload("res://assets/intro/1home.jpg"),
	preload("res://assets/intro/2arrive.png"),
	preload("res://assets/intro/3clock.jpg"),
	preload("res://assets/intro/3clock.jpg"),
	preload("res://assets/intro/4knockout.jpg"),
	preload("res://assets/intro/5desert.jpg"),
	preload("res://assets/intro/6revenge.jpg")
]

var subtitle_lines = [
	"We had a home. We had each other. We had everything that mattered.",
	"Until they came.",
	"Cad Corp took everything from me. My family, my home...",
	"All I have left is my dad's clock.",
	"But I was lucky enough to survive.",
	"Or... that is what I thought.",
	"My family is still out there.",
	"I can feel it.",
	"My journey begins now... and I will bring them home."
]

var subtitle_times = [0.05, 6.7046, 8.8698, 11.4105, 14.1672, 17.6049, 20.8621, 21.9965, 24.2698]
var image_cues = [0, 1, 2, 3, 4, 5, 6]
const VO_OUTPUT_DELAY := 0.15

@onready var image: TextureRect = $Image
@onready var cinematic_text: Control = $CinematicText
@onready var subtitle_text: Label = $CinematicText/Subtitle
@onready var fade: ColorRect = $Fade
@onready var voice_over: AudioStreamPlayer = $VoiceOver

var current_image := 0


func _ready():
	voice_over.volume_db = 0.0
	MusicManager.play_music(intro_music, 1.5, -12.0)
	fade.modulate.a = 1.0

	var fade_in := create_tween()
	fade_in.tween_property(fade, "modulate:a", 0.0, 2.0)
	await fade_in.finished

	if skip_intro:
		return

	voice_over.play()
	await play_intro()


func _unhandled_input(event: InputEvent) -> void:
	# Keep ordinary movement and action keys from accidentally dismissing the
	# opening story. Enter is the single, intentional skip control advertised
	# by the on-screen prompt.
	if not (event is InputEventKey):
		return
	if not event.pressed or event.echo or event.keycode != KEY_ENTER:
		return
	if skip_intro:
		return

	get_viewport().set_input_as_handled()
	skip_intro = true
	start_game()
func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if skip_intro:
			return
		skip_intro = true
		start_game()


func play_intro():
	current_image = 0
	image.texture = images[0]
	image.modulate.a = 1.0
	cinematic_text.modulate.a = 1.0

	while voice_over.playing and voice_over.get_playback_position() < subtitle_times[0] + VO_OUTPUT_DELAY:
		await get_tree().process_frame
	subtitle_text.text = subtitle_lines[0]
	var subtitle_index := 0

	while voice_over.playing:
		if skip_intro:
			return
		var playback_position := voice_over.get_playback_position()
		while subtitle_index + 1 < subtitle_times.size() and playback_position >= subtitle_times[subtitle_index + 1] + VO_OUTPUT_DELAY:
			subtitle_index += 1
			subtitle_text.text = subtitle_lines[subtitle_index]
			var image_index := image_cues.find(subtitle_index)
			if image_index >= 0:
				change_scene(image_index)
		await get_tree().process_frame

	await show_title()


func change_scene(index: int):
	current_image = index
	var transition := create_tween()
	transition.tween_property(image, "modulate:a", 0.0, 0.12)
	transition.tween_callback(func(): image.texture = images[index])
	transition.tween_property(image, "modulate:a", 1.0, 0.24)


func show_title():
	if skip_intro:
		return

	$Title.modulate.a = 0.0
	var title_fade := create_tween()
	title_fade.tween_property($Title, "modulate:a", 1.0, 2.0)
	await title_fade.finished

	if skip_intro:
		return
	await get_tree().create_timer(3.0).timeout

	if skip_intro:
		return
	start_game()


func start_game():
	if voice_over.playing:
		voice_over.stop()
	MusicManager.stop_music(1.0)
	get_tree().change_scene_to_file("res://src/ui/level_title/level_01_title.tscn")
