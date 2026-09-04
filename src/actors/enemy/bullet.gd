class_name Bullet
extends Area2D
## A Gunner's round - what actually carries his shot to the boy, since the
## shipped muzzle-flash art is cropped by its own canvas and never shows the
## round leaving the frame. `Gunner._fire()` spawns one of these instead.
##
## Not a TimeBody2D: there's no gravity or floor to slide against, just a
## straight line at a fixed speed, so position is driven by hand off
## TimeService - the same approach MovingHazard uses for a patrolling saw.
## That's what lets a round freeze in mid-air with the rest of the world
## instead of still finding its mark after the Gunner himself has stopped.
##
## Left live while frozen, same call as Hazard's spinning blades: a stopped
## round is still a solid one, so walking into it still costs a hit.

const LIFETIME := 1.6

@onready var _impact_audio: AudioStreamPlayer2D = get_node_or_null(^"ImpactAudio")

var _velocity := Vector2.ZERO
var _damage := 0.0
var _shooter: Node = null
var _age := 0.0
var _spent := false

func setup(shot_velocity: Vector2, damage: float, shooter: Node) -> void:
	_velocity = shot_velocity
	_damage = damage
	_shooter = shooter
	if not is_zero_approx(shot_velocity.length()):
		rotation = shot_velocity.angle()


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var scaled := TimeService.world_delta(delta)
	if is_zero_approx(scaled):
		return
	global_position += _velocity * scaled
	_age += scaled
	if _age >= LIFETIME:
		queue_free()


## Async so the round can wait out its own impact sound rather than cutting it
## off - `queue_free()` would otherwise kill the AudioStreamPlayer2D the
## instant it starts.
func _on_body_entered(body: Node2D) -> void:
	if _spent:
		return
	var health := body.get(&"health") as HealthComponent
	if health == null or not health.is_alive():
		return
	_spent = true
	health.take_damage(_damage, _shooter)
	_velocity = Vector2.ZERO
	visible = false
	set_deferred(&"monitoring", false)
	if _impact_audio != null:
		_impact_audio.play()
		await _impact_audio.finished
	queue_free()
