extends Node
## Heart pickups, the portrait-and-count HUD, and the death screen's Quit.
## Run with --headless --fixed-fps 60.

const MAP := preload("res://src/levels/level_02/level_02.tscn")
const HEART := preload("res://src/world/pickups/heart_pickup.tscn")
const MAIN_MENU := "res://src/ui/main_menu/main_menu.tscn"

var failures := 0
var level: Level
var player: Player

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

func press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)

## A live level with one heart placed on the entry street, in front of the boy.
func fresh() -> void:
	TimeService.reset()
	if is_instance_valid(level):
		level.queue_free()
		await frames(2)
	level = MAP.instantiate()
	level.debug_spawn_path = NodePath()
	var heart := HEART.instantiate()
	heart.name = "StreetHeart"
	heart.position = Vector2(600, 640)
	level.get_node("World/Pickups").add_child(heart)
	heart.owner = level
	add_child(level)
	get_tree().current_scene = self
	player = level.get_node("Entities/Player")
	level.get_node("Enemies").process_mode = Node.PROCESS_MODE_DISABLED
	level.get_node("World/Hazards").process_mode = Node.PROCESS_MODE_DISABLED
	await frames(2)

func heart() -> Node:
	return level.get_node_or_null("World/Pickups/StreetHeart")

func hud() -> Node:
	return level.get_node("HUD")

func _ready() -> void:
	await pickup_and_hud()
	await cap()
	await portrait_ages()
	await survives_reload()
	await rewind_puts_it_back()
	await chest_hearts()
	await chest_luck()
	# Last, and it does its own reporting: Quit replaces this scene.
	await quit_button()

func pickup_and_hud() -> void:
	GameState.clear_run_progress()
	await fresh()
	check(hud().lives_value.text == "x3", "HUD did not start at x3, got %s" % hud().lives_value.text)
	check(hud().portrait.texture != null, "HUD portrait was empty")
	check(heart().visible, "Heart hidden below the cap")
	player.global_position = Vector2(600, 640)
	await frames(6)
	check(GameState.hearts == 4, "Heart did not add a life, hearts=%d" % GameState.hearts)
	check(hud().lives_value.text == "x4", "HUD did not follow the pickup, got %s" % hud().lives_value.text)
	check(not heart().visible and not heart().monitoring, "Taken heart still on the ground")
	check(GameState.is_heart_collected(&"phase_2", "World/Pickups/StreetHeart"), "Level did not record the heart")
	# Retirement waits on the pickup sound, which runs on the clock rather
	# than on physics frames, so it is not checked here - the fig's is not either.
	print("HEARTS pickup adds a life and the HUD shows it")

func cap() -> void:
	GameState.clear_run_progress()
	GameState.hearts = GameState.HEART_CAP
	EventBus.player_hearts_changed.emit(GameState.hearts, GameState.HEART_CAP)
	await fresh()
	check(not heart().visible, "Heart shown at the cap")
	player.global_position = Vector2(600, 640)
	await frames(6)
	check(GameState.hearts == GameState.HEART_CAP, "Heart went past the cap")
	check(not GameState.is_heart_collected(&"phase_2", "World/Pickups/StreetHeart"), "Heart at the cap was recorded as taken")
	GameState.lose_heart()
	check(heart().visible, "Heart did not come back once a life was lost")
	await frames(6)
	check(GameState.hearts == GameState.HEART_CAP, "Heart under his feet was not taken after a loss")
	print("HEARTS cap holds at %d and the ground heart waits for it" % GameState.HEART_CAP)

func portrait_ages() -> void:
	GameState.clear_run_progress()
	await fresh()
	player.global_position = Vector2(300, 640)
	await frames(2)
	var teen: Texture2D = hud().portrait.texture
	player.age.set_to(30.0)
	await frames(2)
	var adult: Texture2D = hud().portrait.texture
	player.age.set_to(50.0)
	await frames(2)
	var elder: Texture2D = hud().portrait.texture
	check(teen != null and adult != null and elder != null, "A portrait was missing")
	check(teen != adult and adult != elder and teen != elder, "Portrait did not change with age")
	check(adult == PlayerPortrait.MAN and elder == PlayerPortrait.ELDER and teen == PlayerPortrait.BOY, "Portraits do not match the sheets")
	player.age.set_to(20.0)
	await frames(2)
	check(hud().portrait.texture == teen, "Portrait did not come back down with the years")
	print("HEARTS portrait follows the sprite's age lines")

func survives_reload() -> void:
	GameState.clear_run_progress()
	await fresh()
	player.global_position = Vector2(600, 640)
	await frames(6)
	check(GameState.hearts == 4, "Setup: heart not taken")
	GameState.set_checkpoint(&"L2Street", Vector2(300, 640), player.age.age)
	await fresh()
	await frames(2)
	check(heart() == null, "Taken heart was back on the ground after a checkpoint reload")
	check(GameState.hearts == 4, "Reload changed the count")
	print("HEARTS a taken heart stays taken across a reload")

func rewind_puts_it_back() -> void:
	GameState.clear_run_progress()
	await fresh()
	player.global_position = Vector2(300, 640)
	await frames(90)
	player.global_position = Vector2(600, 640)
	await frames(6)
	check(GameState.hearts == 4, "Setup: heart not taken before rewind")
	await frames(30)
	check(player.powers.try_cast(GameState.ABILITY_REWIND), "Rewind refused")
	await frames(240)
	check(not TimeService.is_rewinding(), "Rewind still running")
	check(heart().visible and heart().monitoring, "Rewind did not put the heart back")
	check(not GameState.is_heart_collected(&"phase_2", "World/Pickups/StreetHeart"), "Rewind left the heart recorded as taken")
	check(GameState.hearts == 4, "Rewind took the life back")
	print("HEARTS rewind puts the heart back and keeps the life")

func quit_button() -> void:
	GameState.clear_run_progress()
	await fresh()
	EventBus.player_died.disconnect(level._on_player_died)
	GameState.hearts = 1
	player.global_position = Vector2(300, 640)
	await frames(60)
	player.health.kill()
	var prompt: Node = null
	for i in 90:
		await frames(1)
		if player.has_node("GameOver"):
			prompt = player.get_node("GameOver")
			break
	check(prompt != null, "Game Over screen did not appear on the last heart")
	if prompt == null:
		return
	check(prompt.quit_button != null and prompt.quit_button.text == "[Q] QUIT TO MENU", "Quit button missing")
	check(prompt.restart_button.has_focus(), "Focus left Restart")
	check(get_tree().paused, "Game Over did not pause")
	if failures > 0 and prompt == null:
		return
	# Quit replaces the current scene - this node - so a watcher outside it
	# reports what the tree looks like afterwards and prints the verdict.
	var watcher := Node.new()
	watcher.name = "QuitWatcher"
	watcher.process_mode = Node.PROCESS_MODE_ALWAYS
	var script := GDScript.new()
	script.source_code = """
extends Node
func _ready() -> void:
	for i in 30:
		await get_tree().process_frame
	var scene := get_tree().current_scene
	var ok := scene != null and scene.scene_file_path == "%s" and not get_tree().paused
	if not ok:
		push_error("Quit did not land on the menu unpaused: %%s paused=%%s" %% [scene.scene_file_path if scene else "none", get_tree().paused])
	var failures := %d + (0 if ok else 1)
	print("HEARTS quit leaves for the menu with hearts=%%d" %% GameState.hearts)
	print("LEVEL_02_HEARTS_VERIFIED failures=%%d" %% failures)
	get_tree().quit(1 if failures else 0)
""" % [MAIN_MENU, failures]
	script.reload()
	watcher.set_script(script)
	get_tree().root.add_child(watcher)
	press_key(KEY_Q)

## Every supply chest holds a heart: the lid opens for it even at full health,
## it springs out, lands within reach, and a retry does not put it back.
func chest_hearts() -> void:
	GameState.clear_run_progress()
	GameState.heart_rolls["phase_2|World/Supplies/YardSupply/Heart"] = true
	await fresh()
	var chest: Node = level.get_node("World/Supplies/YardSupply")
	var stowed: Node = chest.get_node("Heart")
	check(not stowed.visible and not stowed.monitoring, "Stowed heart was out before the chest opened")
	player.health.current = player.health.max_health
	player.global_position = chest.global_position
	await frames(3)
	check(chest.opened and not chest.healed, "Chest did not open for its heart at full health, or wasted its healing")
	check(stowed.visible and not stowed.monitoring and GameState.hearts == 3, "Heart was taken mid-spring")
	for i in 90:
		await frames(1)
		if stowed.monitoring:
			break
	check(stowed.monitoring, "Heart never landed")
	check(stowed.position.is_equal_approx(Vector2(0, -32) + HeartPickup.REST), "Heart did not settle at rest: %s" % stowed.position)
	await frames(3)
	check(GameState.hearts == 4, "Landed heart was not taken by the boy at the box")
	check(GameState.is_heart_collected(&"phase_2", "World/Supplies/YardSupply/Heart"), "Chest heart not recorded")
	# A retry: the chest is shut again, but its heart is gone.
	GameState.set_checkpoint(&"L2MachineYard", Vector2(1691, 652), player.age.age)
	await fresh()
	chest = level.get_node("World/Supplies/YardSupply")
	await frames(2)
	check(chest.get_node_or_null("Heart") == null, "Taken chest heart came back on a retry")
	player.health.current = player.health.max_health
	player.global_position = chest.global_position
	await frames(3)
	check(not chest.opened, "Emptied chest opened with nothing useful inside")
	player.health.current = 40.0
	await frames(3)
	check(chest.opened and chest.healed and player.health.current == 90.0, "Emptied chest stopped healing")
	# At the cap the lid stays shut unless he needs health; a rewind past the
	# opening stows the heart again.
	GameState.clear_run_progress()
	GameState.heart_rolls["phase_2|World/Supplies/YardSupply/Heart"] = true
	GameState.hearts = GameState.HEART_CAP
	await fresh()
	chest = level.get_node("World/Supplies/YardSupply")
	player.health.current = player.health.max_health
	player.global_position = chest.global_position
	await frames(3)
	check(not chest.opened, "Chest opened for a heart at the cap")
	player.global_position = Vector2(2600, 574)
	await frames(90)
	GameState.hearts = 3
	player.global_position = chest.global_position
	await frames(3)
	check(chest.opened and chest.get_node("Heart").visible, "Yard chest did not release its heart")
	player.global_position = Vector2(2600, 574)
	await frames(6)
	check(player.powers.try_cast(GameState.ABILITY_REWIND), "Rewind refused")
	await frames(240)
	check(not chest.opened and not chest.get_node("Heart").visible and not chest.get_node("Heart").monitoring, "Rewind did not stow the heart with the closed chest")
	print("HEARTS chests hold a heart: open, spring, land, taken, gone on retry, stowed on rewind")


## Which chests hold a heart is luck, rolled once per run: a retry finds the
## same boxes full, a new run rolls again.
func chest_luck() -> void:
	GameState.clear_run_progress()
	var chests := ["StreetCache", "YardSupply", "RoofCache", "CourtyardCache", "ExitSupply"]
	var luck := [true, false, true, false, false]
	for i in chests.size():
		GameState.heart_rolls["phase_2|World/Supplies/%s/Heart" % chests[i]] = luck[i]
	for attempt in 2:
		await fresh()
		await frames(2)
		for i in chests.size():
			var has: bool = level.get_node("World/Supplies/%s" % chests[i]).get_node_or_null("Heart") != null
			check(has == luck[i], "%s heart presence %s did not match the roll on attempt %d" % [chests[i], has, attempt])
		GameState.set_checkpoint(&"L2MachineYard", Vector2(1691, 652), player.age.age)
	# A run that has not rolled yet rolls at the box's own chance and keeps it.
	GameState.clear_run_progress()
	check(GameState.heart_rolls.is_empty(), "A new run kept the old luck")
	var chance: float = load("res://src/levels/level_02/objects/supply_chest.tscn").instantiate().get_node("Heart").chance
	check(chance > 0.0 and chance < 1.0, "Chest hearts are not a gamble: chance %s" % chance)
	await fresh()
	await frames(2)
	# Every heart in the level rolls - these five, the two arena chests and the
	# loose one this fixture plants.
	check(GameState.heart_rolls.size() >= chests.size(), "Level did not roll every chest, rolled %d" % GameState.heart_rolls.size())
	var rolled := GameState.heart_rolls.duplicate()
	for i in chests.size():
		var has: bool = level.get_node("World/Supplies/%s" % chests[i]).get_node_or_null("Heart") != null
		check(has == rolled["phase_2|World/Supplies/%s/Heart" % chests[i]], "%s did not follow its roll" % chests[i])
	print("HEARTS chest luck is rolled once per run and holds across retries")
