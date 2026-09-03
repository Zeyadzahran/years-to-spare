extends CanvasLayer
## Reads the game through EventBus only, so it can be dropped into any level
## without being wired to the player.

@onready var health_label: Label = %Health
@onready var age_label: Label = %Age
@onready var time_label: Label = %TimeMode
@onready var options_button: Button = %Options

const OPTIONS_SCENE := preload("res://scenes/options.tscn")

var _options_panel: Control = null

func _ready() -> void:
	# Stay responsive while the options overlay pauses the level.
	process_mode = Node.PROCESS_MODE_ALWAYS
	options_button.pressed.connect(_on_options_pressed)
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.player_age_changed.connect(_on_age_changed)
	EventBus.time_mode_changed.connect(_on_time_mode_changed)
	EventBus.player_spawned.connect(_read_player)
	_on_time_mode_changed(TimeService.mode)
	# The player may already exist: pull the starting values instead of waiting
	# for the first change.
	_read_player(get_tree().get_first_node_in_group(&"player"))


func _read_player(player: Node) -> void:
	if player == null:
		return
	_on_health_changed(player.health.current, player.health.max_health)
	_on_age_changed(player.age.age, player.age.death_age)


func _on_health_changed(current: float, maximum: float) -> void:
	health_label.text = "HP  %d / %d" % [roundi(current), roundi(maximum)]


func _on_age_changed(age: float, death_age: float) -> void:
	age_label.text = "AGE  %d / %d" % [roundi(age), roundi(death_age)]


func _on_time_mode_changed(mode: int) -> void:
	time_label.text = "TIME  %s" % TimeService.Mode.keys()[mode]


func _unhandled_input(event: InputEvent) -> void:
	# The panel closes itself on the same key, so only open when it is gone.
	if is_instance_valid(_options_panel):
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_options_pressed()


func _on_options_pressed() -> void:
	if is_instance_valid(_options_panel):
		return
	_options_panel = OPTIONS_SCENE.instantiate()
	_options_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	# Closing returns to the level instead of the main menu.
	_options_panel.set("overlay", true)
	_options_panel.tree_exited.connect(_on_options_closed)
	add_child(_options_panel)
	get_tree().paused = true


func _on_options_closed() -> void:
	_options_panel = null
	# Skip when the whole level is being torn down, e.g. leaving for the menu.
	if not is_inside_tree():
		return
	get_tree().paused = false
