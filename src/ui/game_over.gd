extends CanvasLayer
## The run is over: his last heart is gone, or his years are. Nothing is
## committed until he chooses - the tree is paused under this - and the choice
## is only ever restart or leave. A death that still leaves him a heart never
## comes here; it costs the heart and puts him back at the marker on its own.

const FONT := preload("res://assets/fonts/prstart.ttf")
const MAIN_MENU_SCENE := "res://src/ui/main_menu/main_menu.tscn"
var player: Player
var restart_button: Button
var quit_button: Button
var _resolved := false
var _owns_pause := false


func _ready() -> void:
	name = "GameOver"
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build()
	_owns_pause = true
	get_tree().paused = true
	restart_button.grab_focus()


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.025, 0.035, 0.065, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 22)
	center.add_child(rows)
	_lives(rows)
	_label(rows, "GAME OVER", 36, Color(1.0, 0.45, 0.35))
	var reason := "Your time has run out." if _of_old_age() else "No hearts left."
	_label(rows, "%s  The level starts over with %d." % [reason, GameState.MAX_HEARTS], 12, Color(0.84, 0.84, 0.88))
	restart_button = _button(rows, "[ENTER] RESTART LEVEL", _choose_restart)
	quit_button = _button(rows, "[Q] QUIT TO MENU", _choose_quit)


## The face he died wearing and the count that ran out.
func _lives(parent: Node) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var face := TextureRect.new()
	face.texture = PlayerPortrait.texture_for(player.sprite.sprite_frames, player.sprite)
	face.custom_minimum_size = Vector2(44, 44)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	row.add_child(face)
	var count := Label.new()
	count.text = "x%d" % maxi(GameState.hearts - 1, 0)
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count.add_theme_font_override("font", FONT)
	count.add_theme_font_size_override("font_size", 16)
	count.add_theme_color_override("font_color", Color(0.94, 0.86, 0.84))
	row.add_child(count)


func _label(parent: Node, text: String, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(500, 56)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 16)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.14)
	style.set_border_width_all(2)
	style.border_color = Color(0.35, 0.43, 0.53)
	button.add_theme_stylebox_override("normal", style)
	var focused := style.duplicate() as StyleBoxFlat
	focused.border_color = Color(1.0, 0.78, 0.38)
	button.add_theme_stylebox_override("focus", focused)
	button.add_theme_stylebox_override("hover", focused)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _input(event: InputEvent) -> void:
	if _resolved:
		return
	# Consume before Restart can replace the current scene and remove this node.
	if event is InputEventKey or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			_choose_restart()
		elif event.keycode == KEY_Q:
			_choose_quit()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		_choose_restart()


func _of_old_age() -> bool:
	return player.age.age >= player.age.death_age


## Commits the death through the level, which spends the last heart, throws
## the run's progress away and reloads from the top.
func _choose_restart() -> void:
	if _resolved:
		return
	var old_age := _of_old_age()
	_close()
	EventBus.player_died.emit(old_age)


## Nothing is committed: PLAY on the menu clears the run - the pause menu's
## MAIN MENU leaves it the same way (src/ui/options/options.gd).
func _choose_quit() -> void:
	if _resolved:
		return
	_close()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _close() -> void:
	_resolved = true
	hide()
	_owns_pause = false
	get_tree().paused = false
	queue_free()


func _exit_tree() -> void:
	if _owns_pause:
		get_tree().paused = false
