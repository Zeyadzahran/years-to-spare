extends CanvasLayer
## Pausing the tree preserves the rewind buffer and cooldowns while choosing.
## Only Continue commits the death through the existing level retry flow.

signal rewind_chosen

const MAIN_MENU_SCENE := "res://src/ui/main_menu/main_menu.tscn"
const FONT := preload("res://assets/fonts/prstart.ttf")
var player: Player
var rewind_button: Button
var continue_button: Button
var quit_button: Button
var _resolved := false
var _owns_pause := false


func _ready() -> void:
	name = "DeathPrompt"
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	# A Rewind pressed on the last frame of the collapse already owns the death.
	if not player.is_down() or player.powers.is_casting(GameState.ABILITY_REWIND):
		rewind_chosen.emit()
		queue_free()
		return
	_build()
	_owns_pause = true
	get_tree().paused = true
	continue_button.grab_focus()


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
	_label(rows, "YOU DIED", 36, Color(1.0, 0.45, 0.35))
	var restart := GameState.hearts <= 1 or player.age.age >= player.age.death_age
	var consequence := "Continue uses 1 heart.  %d remaining." % (GameState.hearts - 1)
	if restart:
		consequence = "Restart the level with %d hearts." % GameState.MAX_HEARTS
	_label(rows, consequence, 12, Color(0.84, 0.84, 0.88))
	var reason := player.powers.death_rewind_block_reason()
	rewind_button = _button(rows, "[L] REWIND", _choose_rewind)
	rewind_button.visible = reason.is_empty()
	if reason.is_empty():
		_label(rows, "Keep your heart.  Rewind costs 4 years.", 10, Color(0.55, 0.83, 0.94))
	else:
		_label(rows, reason, 12, Color(0.68, 0.69, 0.75))
	var continue_text := "[ENTER] RESTART LEVEL" if restart else "[ENTER] CONTINUE"
	continue_button = _button(rows, continue_text, _choose_continue)
	quit_button = _button(rows, "[Q] QUIT TO MENU", _choose_quit)


## Show the current lives: no heart is spent until Continue is chosen.
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
	count.text = "x%d" % GameState.hearts
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
	# Consume before Continue can replace the current scene and remove this node.
	if event is InputEventKey or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()
	if event.is_action_pressed(&"time_rewind"):
		_choose_rewind()
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_choose_continue()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		_choose_quit()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		_choose_continue()


func _choose_rewind() -> void:
	if _resolved or not player.powers.rewind_after_death():
		return
	rewind_chosen.emit()
	_close()


func _choose_continue() -> void:
	if _resolved:
		return
	var old_age := player.age.age >= player.age.death_age
	_close()
	EventBus.player_died.emit(old_age)


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
