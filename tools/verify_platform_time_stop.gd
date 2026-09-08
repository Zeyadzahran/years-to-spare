extends Node
## The optional power still costs three years and freezes/resumes all four decks.

const FIXTURE = preload("res://tools/level_01_fixture.gd")


func _ready() -> void:
	GameState.start_new_run()
	var section := FIXTURE.late_sections()
	section.get_node(^"Enemies").free()
	add_child(section)
	var player := (load("res://src/actors/player/player.tscn") as PackedScene).instantiate() as Player
	player.position = Vector2(14800, 117)
	add_child(player)
	player.get_node(^"Camera2D").enabled = false
	await get_tree().physics_frame
	var before := player.age.age
	Input.action_press(&"time_stop")
	# process_frame resumes before nodes process input; allow that full frame.
	await get_tree().process_frame
	await get_tree().process_frame
	Input.action_release(&"time_stop")
	assert(player.powers.is_winding_up())
	assert(is_equal_approx(player.age.age, before + 3.0))
	player.powers._process(TimePowers.WIND_UP + 0.01)
	assert(TimeService.mode == TimeService.Mode.STOPPED)
	# AnimatableBody2D applies the last submitted transform at the physics sync.
	await get_tree().physics_frame
	await get_tree().physics_frame
	var frozen := {}
	for deck in section.get_node(^"Platforms").get_children():
		if deck is MovingPlatform:
			frozen[deck] = deck.position
	assert(frozen.size() == 4)
	for _frame in range(20):
		await get_tree().physics_frame
	for deck: MovingPlatform in frozen:
		assert(deck.position.is_equal_approx(frozen[deck]), "%s drift %s -> %s" % [deck.name, frozen[deck], deck.position])
	player.powers.cancel()
	assert(TimeService.mode == TimeService.Mode.NORMAL)
	for _frame in range(20):
		await get_tree().physics_frame
	for deck: MovingPlatform in frozen:
		assert(not deck.position.is_equal_approx(frozen[deck]))
	print("PLATFORM_TIME_STOP_OK decks=4 cost=3 freeze=true resume=true")
	player.queue_free()
	section.queue_free()
	await get_tree().process_frame
	get_tree().quit()
