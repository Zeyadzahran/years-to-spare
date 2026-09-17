class_name BossExplosion
extends AnimatedSprite2D
## One-shot red explosion used for the Level 2 Business Man's death.

signal finished

## The boss samples this effect from its rewindable transition clock.
var controlled := false

func _ready() -> void:
	if controlled:
		stop()
		return
	animation_finished.connect(_on_animation_finished)
	play(&"explode")

func _on_animation_finished() -> void:
	finished.emit()
	queue_free()
