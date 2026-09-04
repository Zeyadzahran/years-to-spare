class_name Enemy
extends TimeBody2D
## Base for every Cad Corp unit: health, death and the time-obeying tick.
## Guard, Gunner and Charger subclass this and implement `_tick` only.

## Years the player takes back for killing this unit.
@export var age_reward := 2.0

@onready var health: HealthComponent = $Health
## Optional: the noise this unit makes when its own attack lands on the boy.
## Each scene brings its own take - a baton across the back is not a round going
## into flesh - so the stream lives on the node, not here.
@onready var hit_audio: AudioStreamPlayer2D = get_node_or_null(^"HitAudio")

func _ready() -> void:
	add_to_group(&"enemy")
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	var scaled := world_delta(delta)
	if is_zero_approx(scaled):
		return
	apply_gravity(scaled)
	_tick(scaled)
	move_in_time()


## Subclass AI. `delta` is already scaled by the player's time powers.
func _tick(_delta: float) -> void:
	pass


## For subclasses to call the moment their attack connects. Restarted rather
## than left to finish, so a second blow sounds like a second blow.
func play_hit_audio() -> void:
	if hit_audio != null:
		hit_audio.play()


func _on_died() -> void:
	EventBus.enemy_died.emit(self, age_reward)
	queue_free()
