extends CanvasLayer
## Reads the game through EventBus only, so it can be dropped into any level
## without being wired to the player.

@onready var health_bar: StatBar = %Health
@onready var health_value: Label = %HealthValue
## The years meter. Every power the boy holds drains it, so it doubles as the
## charge on his abilities - hence the name.
@onready var power_line: StatBar = %PowerLine
@onready var power_value: Label = %PowerValue
@onready var pear_count: Label = %PearCount
@onready var time_label: Label = %TimeMode
@onready var options_button: Button = %Options

const OPTIONS_SCENE := preload("res://scenes/options.tscn")

var _options_panel: Control = null

## The age the run started at - the power line's zero point. The age signal
## only carries the current and the death age, so this is read off the player.
var _start_age := 14.0

func _ready() -> void:
	# Stay responsive while the options overlay pauses the level.
	process_mode = Node.PROCESS_MODE_ALWAYS
	options_button.pressed.connect(_on_options_pressed)
	EventBus.player_health_changed.connect(_on_health_changed)
	EventBus.player_heals_changed.connect(_on_heals_changed)
	EventBus.player_age_changed.connect(_on_age_changed)
	EventBus.time_mode_changed.connect(_on_time_mode_changed)
	EventBus.player_spawned.connect(_read_player)
	EventBus.ability_started.connect(_on_ability_changed.bind(true))
	EventBus.ability_stopped.connect(_on_ability_changed.bind(false))
	_on_time_mode_changed(TimeService.mode)
	# The player may already exist: pull the starting values instead of waiting
	# for the first change.
	_read_player(get_tree().get_first_node_in_group(&"player"))


func _read_player(player: Node) -> void:
	if player == null:
		return
	_start_age = player.age.start_age
	_on_health_changed(player.health.current, player.health.max_health)
	_on_age_changed(player.age.age, player.age.death_age)
	_on_heals_changed(player.heal_charges)


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.set_value(current, maximum)
	health_value.text = "%d" % roundi(current)


## The clock plate reads as the boy's age, not as a stock of years: it starts at
## 14 and fills towards 60, so holding a power visibly walks him to the end of
## his life rather than draining an abstract meter.
func _on_age_changed(age: float, death_age: float) -> void:
	var span := maxf(death_age - _start_age, 0.001)
	power_line.set_value(age - _start_age, span)
	power_value.text = "%d" % roundi(age)


func _on_heals_changed(count: int) -> void:
	pear_count.text = "x%d" % count


func _on_ability_changed(_ability_id: StringName, active: bool) -> void:
	power_line.channelling = active


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
