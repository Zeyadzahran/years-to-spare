extends CanvasLayer
## Reads the game through EventBus only, so it can be dropped into any level
## without being wired to the player.

@onready var health_label: Label = %Health
@onready var age_label: Label = %Age
@onready var time_label: Label = %TimeMode

func _ready() -> void:
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
