class_name Hazard
extends Area2D
## A damage volume wrapped around a piece of hazard art. Spikes, saws and acid
## all use this; the sprite stays a plain child so the art and the danger can be
## adjusted independently.
##
## Hazards chip rather than kill: a mistake costs a fifth of the bar and the
## walk back to the next fig, not the run. Raise `damage` past max health for
## the one pit that is meant to be final.

@export var damage := 20.0

## Seconds before the same body can be hurt again, so standing in acid does not
## drain a hit every frame.
@export var cooldown := 0.75

## Disable for hazards whose danger comes from motion, such as a spinning saw.
@export var hurts_while_frozen := true

## Cooldown left per body, keyed by instance id rather than by the body itself:
## a typed Node2D key rejects every read and erase once that body is freed,
## which would strand the entry and error on each frame after.
var _cooldowns: Dictionary[int, float] = {}

## Animated art and sound, if the hazard has any. Looping, frame rate and volume
## are authored on those nodes; only the clock they run on is decided here.
var _animation: AnimatedSprite2D
var _audio: AudioStreamPlayer2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	for child in get_children():
		if _animation == null and child is AnimatedSprite2D:
			_animation = child
		elif _audio == null and child is AudioStreamPlayer2D:
			_audio = child


## Left running rather than toggled off when idle, so a subclass can drive
## movement from here without the cooldown bookkeeping switching it off.
func _physics_process(delta: float) -> void:
	# Art and sound run on world time like hazard movement does, so a stopped
	# world stops the blade spinning, the acid pouring and the saw howling.
	if _animation != null:
		_animation.speed_scale = TimeService.world_scale
	if _audio != null:
		_audio.stream_paused = TimeService.is_world_frozen()
	for id in _cooldowns.keys():
		_cooldowns[id] -= delta
		if _cooldowns[id] <= 0.0:
			_cooldowns.erase(id)
	# A body that never leaves keeps taking hits once its cooldown expires.
	for body in get_overlapping_bodies():
		_hurt(body)


func _on_body_entered(body: Node2D) -> void:
	_hurt(body)


func _hurt(body: Node2D) -> void:
	if not hurts_while_frozen and TimeService.is_world_frozen():
		return
	var id := body.get_instance_id()
	if _cooldowns.has(id):
		return
	var health := body.get(&"health") as HealthComponent
	if health == null or not health.is_alive():
		return
	_cooldowns[id] = cooldown
	health.take_damage(damage, self)
