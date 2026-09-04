extends Control

var skip_intro := false

var intro_music = preload("res://assets/music/A_Bridge_to_Yesterday.mp3")

var images = [
	preload("res://assets/intro/1home.jpg"),
	preload("res://assets/intro/2arrive.png"),
	preload("res://assets/intro/3clock.jpg"),
	preload("res://assets/intro/4knockout.jpg"),
	preload("res://assets/intro/5desert.jpg"),
	preload("res://assets/intro/6revenge.jpg")
]

var subtitles = [
	"We had a home. We had each other. We had everything that mattered.",
	"Until they came.",
	"Cad Corp took everything from me. My family, my home... all I have left is my dad's clock.",
	"But I was lucky enough to survive.",
	"Or that is what I thought.",
	"My family is still out there. I can feel it. My journey begins now... and I will bring them home."
]

# Time in the voice-over when each scene should start.
var scene_times = [
	0.0,   # Scene 1
	5.8,   # Scene 2
	7.5,   # Scene 3
	13.3,  # Scene 4
	17.2,  # Scene 5
	20.4   # Scene 6
]

@onready var image: TextureRect = $Image
@onready var subtitle: Label = $Subtitle
@onready var fade: ColorRect = $Fade
@onready var voice_over: AudioStreamPlayer = $VoiceOver

var current_image := 0


func _ready():
	# Voice-over should be clearly louder than the background music.
	voice_over.volume_db = 0.0

	# Start background music at a lower volume.
	MusicManager.play_music(intro_music, 1.5, -12.0)

	# Start with a black screen.
	fade.modulate.a = 1.0

	var tween = create_tween()
	tween.tween_property(
		fade,
		"modulate:a",
		0.0,
		2.0
	)

	await tween.finished

	if skip_intro:
		return

	# Start narration.
	voice_over.play()

	# Start the visual intro.
	await play_intro()


func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		if skip_intro:
			return

		skip_intro = true
		start_game()


func play_intro():
	# Show the first scene immediately.
	current_image = 0

	image.texture = images[0]
	subtitle.text = subtitles[0]

	image.modulate.a = 1.0
	subtitle.modulate.a = 1.0

	# Wait for each scene's timestamp according to the voice-over.
	for i in range(1, images.size()):

		while voice_over.playing:
			if skip_intro:
				return

			var current_time = voice_over.get_playback_position()

			if current_time >= scene_times[i]:
				break

			await get_tree().process_frame

		if skip_intro:
			return

		await change_scene(i)

		if skip_intro:
			return

	# Wait for the voice-over to finish.
	while voice_over.playing:
		if skip_intro:
			return

		await get_tree().process_frame

	await show_title()


func change_scene(index: int):
	current_image = index

	# Fade the old image and subtitle out.
	var tween = create_tween()

	tween.parallel().tween_property(
		image,
		"modulate:a",
		0.0,
		0.4
	)

	tween.parallel().tween_property(
		subtitle,
		"modulate:a",
		0.0,
		0.4
	)

	await tween.finished

	if skip_intro:
		return

	# Change the image and subtitle.
	image.texture = images[index]
	subtitle.text = subtitles[index]

	# Start invisible.
	image.modulate.a = 0.0
	subtitle.modulate.a = 0.0

	# Fade the new scene in.
	tween = create_tween()

	tween.parallel().tween_property(
		image,
		"modulate:a",
		1.0,
		0.4
	)

	tween.parallel().tween_property(
		subtitle,
		"modulate:a",
		1.0,
		0.4
	)

	await tween.finished


func show_title():
	if skip_intro:
		return

	$Title.modulate.a = 0.0

	var tween = create_tween()

	tween.tween_property(
		$Title,
		"modulate:a",
		1.0,
		2.0
	)

	await tween.finished

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

	get_tree().change_scene_to_file(
		"res://src/levels/garbage_eden.tscn"
	)
