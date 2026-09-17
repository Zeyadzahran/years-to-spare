class_name BusinessDisappearEffect
extends AnimatedSprite2D

signal finished

## The boss samples this effect from its rewindable transition clock.
var controlled := false

func _ready() -> void:
	if controlled:
		stop()
		return
	animation_finished.connect(_on_animation_finished)
	play(&"disappear")

func _on_animation_finished() -> void:
	finished.emit()
	queue_free()
