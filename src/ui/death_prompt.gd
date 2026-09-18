extends CanvasLayer
## Pausing the tree preserves the rewind buffer and cooldowns while choosing.
## Rewind expires after three seconds; only Continue commits the death.

signal rewind_chosen

const REWIND_WINDOW := 3.0
const MAIN_MENU_SCENE := "res://src/ui/main_menu/main_menu.tscn"
const FONT := preload("res://assets/fonts/prstart.ttf")
var player: Player
var rewind_button: Button
var continue_button: Button
var quit_button: Button
var _rewind_time_left := REWIND_WINDOW
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
	var restart := GameState.hearts <= 1 or player.age.age >= player.age.death_age
	rewind_button = _button(rows, "[L] REWIND", _choose_rewind)
	rewind_button.visible = player.powers.death_rewind_block_reason().is_empty()
	var continue_text := "[ENTER] RESTART LEVEL" if restart else "[ENTER] CONTINUE"
	continue_button = _button(rows, continue_text, _choose_continue)
	quit_button = _button(rows, "[Q] QUIT TO MENU", _choose_quit)


## This layer keeps processing while the world and its rewind history are paused.
func _process(delta: float) -> void:
	if _resolved or not _owns_pause or not rewind_button.visible:
		return
	_rewind_time_left = maxf(_rewind_time_left - delta, 0.0)
	if is_zero_approx(_rewind_time_left):
		if rewind_button.has_focus():
			continue_button.grab_focus()
		rewind_button.disabled = true
		rewind_button.hide()


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
	if _resolved or _rewind_time_left <= 0.0 or not rewind_button.visible:
		return
	if not player.powers.rewind_after_death():
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
