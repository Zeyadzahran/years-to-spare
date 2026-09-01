class_name PlayerState
extends State
## Shared base so every player state can reach the controller with a real type.

var player: Player

func setup() -> void:
	player = host as Player
