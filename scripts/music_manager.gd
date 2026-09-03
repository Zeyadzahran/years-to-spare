extends Node

var player: AudioStreamPlayer
var current_song: AudioStream
var fade_tween: Tween


func _ready():
	player = AudioStreamPlayer.new()
	add_child(player)


func play_music(song: AudioStream, fade_time := 1.0):
	if song == current_song and player.playing:
		return

	current_song = song

	if fade_tween:
		fade_tween.kill()

	if player.playing:
		fade_tween = create_tween()
		fade_tween.tween_property(player, "volume_db", -40.0, fade_time)
		await fade_tween.finished

	player.stream = song
	player.volume_db = -40.0
	player.play()

	fade_tween = create_tween()
	fade_tween.tween_property(player, "volume_db", 0.0, fade_time)


func stop_music(fade_time := 1.0):
	if not player.playing:
		return

	if fade_tween:
		fade_tween.kill()

	fade_tween = create_tween()
	fade_tween.tween_property(player, "volume_db", -40.0, fade_time)
	await fade_tween.finished

	player.stop()
	current_song = null
