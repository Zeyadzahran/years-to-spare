class_name ReinforcementGate
extends Node2D
## Temporary portal used when the Business Man calls in robot reinforcements.
## The gate is purely visual here; the Level 2 boss arena owns spawning.

@export var appear_scale := Vector2(0.72, 0.72)

func _ready() -> void:
	$Glow.modulate.a = 0.0
	$Art.modulate.a = 0.0
	$Art.scale = Vector2.ZERO
	$Glow.scale = Vector2.ZERO

func open() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property($Art, ^"scale", appear_scale, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property($Art, ^"modulate:a", 1.0, 0.24)
	tween.tween_property($Glow, ^"scale", appear_scale * 1.04, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property($Glow, ^"modulate:a", 0.48, 0.30)
	await tween.finished

func close() -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property($Art, ^"scale", Vector2.ZERO, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property($Art, ^"modulate:a", 0.0, 0.20)
	tween.tween_property($Glow, ^"scale", Vector2.ZERO, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property($Glow, ^"modulate:a", 0.0, 0.20)
	await tween.finished
