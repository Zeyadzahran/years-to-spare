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
	# The sprite runs on its own clock (AnimatedSprite2D advances every process
	# frame, not just physics ticks the AI takes), so it has to be leashed to
	# world time explicitly here. Otherwise a Guard frozen mid-swing or a
	# Gunner frozen mid-shot keeps flipping frames while the boy walks past -
	# time stops for what the unit *does*, but not for what it *shows*.
	_sync_sprite_to_world_time()
	var scaled := world_delta(delta)
	if is_zero_approx(scaled):
		return
	apply_gravity(scaled)
	_tick(scaled)
	move_in_time()


## Every AnimatedSprite2D child is leashed to TimeService rather than just the
## one subclasses happen to name `sprite`, so this keeps working even for a
## unit with a second sprite (a muzzle flash, a weapon overlay, ...).
func _sync_sprite_to_world_time() -> void:
	# Named away from `scale`: Node2D already owns that property, and shadowing
	# it here would silently read/write the wrong thing.
	var time_scale := TimeService.world_scale
	for child in get_children():
		if child is AnimatedSprite2D:
			child.speed_scale = time_scale


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
