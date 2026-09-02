extends Control

var skip_intro := false

var images = [
	preload("res://assets/intro/1home.jpg"),
	preload("res://assets/intro/2arrive.png"),
	preload("res://assets/intro/3clock.jpg"),
	preload("res://assets/intro/4knockout.jpg"),
	preload("res://assets/intro/5desert.jpg"),
	preload("res://assets/intro/6revenge.jpg")
]

@onready var image: TextureRect = $Image
@onready var subtitle: Label = $Subtitle
@onready var music: AudioStreamPlayer = $Music
@onready var fade: ColorRect = $Fade
var current_image := 0

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and not event.echo:
		skip_intro = true
		start_game()

var durations = [
	6.0,  # Family
	5.0,  # Soldiers arrive
	6.0,  # Handing Clock
	7.0,  # Unconsciousness
	6.0,  # Awakening
	5.0,  # Revenge
]

var subtitles = [
	"We had a home. We had each other. We had everything that mattered.",
	"Until they came.",
	"Cad Corp took everything from me. My family, my home... all I have left is my dad's clock.",
	"But I was lucky enough to survive.",
	"Or that is what I thought.",
	"My family is still out there. I can feel it. My journey begins now... and I will bring them home."
]

func fade_in():
	var tween = create_tween()

	image.modulate.a = 0.0
	subtitle.modulate.a = 0.0

	tween.parallel().tween_property(
		image,
		"modulate:a",
		1.0,
		1.2
	)

	tween.parallel().tween_property(
		subtitle,
		"modulate:a",
		1.0,
		1.2
	)

	await tween.finished

func fade_out():
	var tween = create_tween()

	tween.parallel().tween_property(
		image,
		"modulate:a",
		0.0,
		1.0
	)

	tween.parallel().tween_property(
		subtitle,
		"modulate:a",
		0.0,
		1.0
	)

	await tween.finished

func play_scene(index: int):
	image.texture = images[index]
	subtitle.text = subtitles[index]

	await fade_in()

	await get_tree().create_timer(
		durations[index]
	).timeout

	await fade_out()

func start_game():
	get_tree().change_scene_to_file("res://src/levels/garbage_eden.tscn")

func show_title():
	$Title.modulate.a = 0.0

	var tween = create_tween()

	tween.tween_property(
		$Title,
		"modulate:a",
		1.0,
		2.0
	)

	await tween.finished

	await get_tree().create_timer(3.0).timeout

	start_game()
func play_intro():
	for i in range(images.size()):
		await play_scene(i)

	await show_title()

func _ready():
	fade.modulate.a = 1.0

	var tween = create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, 2.0)

	await tween.finished

	await play_intro()
