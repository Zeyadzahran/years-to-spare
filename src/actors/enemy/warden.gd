class_name Warden
extends Guard
## Final exam: a heavy guard whose arena changes twice without locking the player.

var _phase := 1
var _victory := false


func _init() -> void:
	super()
	speed = 285.0
	damage = 40.0
	attack_range = 76.0
	attack_recovery = 0.48
	knockback = 340.0
	age_reward = 8.0
	patrol_distance = 260.0
	territory = 920.0


func _ready() -> void:
	super()
	$Victory/Panel.visible = false
	for unit in get_tree().get_nodes_in_group(&"warden_phase_two"):
		unit.detection_range = 0.0
	for hazard in get_tree().get_nodes_in_group(&"warden_phase_three"):
		hazard.monitoring = false
		hazard.visible = false


func _physics_process(delta: float) -> void:
	if not _victory and health != null and health.max_health > 0.0:
		var ratio := health.current / health.max_health
		if _phase == 1 and ratio <= 0.6:
			_phase = 2
			speed = 320.0
			for unit in get_tree().get_nodes_in_group(&"warden_phase_two"):
				unit.detection_range = 440.0
		if _phase == 2 and ratio <= 0.3:
			_phase = 3
			speed = 365.0
			attack_recovery = 0.32
			for hazard in get_tree().get_nodes_in_group(&"warden_phase_three"):
				hazard.visible = true
				hazard.set_deferred(&"monitoring", true)
	super(delta)


func _process(_delta: float) -> void:
	if _victory and Input.is_action_just_pressed(&"attack"):
		get_tree().paused = false
		GameState.clear_run_progress()
		get_tree().change_scene_to_file("res://src/levels/main_menu.tscn")


func _on_animation_finished() -> void:
	if sprite.animation == &"dying" and state == &"Dead" and not _victory:
		_victory = true
		var level := get_tree().current_scene as Level
		if level != null:
			level.complete()
		$Victory/Panel.visible = true
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true
		return
	super()
