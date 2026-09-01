class_name State
extends Node
## One behaviour of a state machine. States never switch state directly; they
## return the next state's name, which keeps every transition visible in the
## state that causes it.

var host: Node
var machine: StateMachine

## Called once by the StateMachine after `host` and `machine` are assigned.
func setup() -> void:
	pass


func enter(_previous: StringName) -> void:
	pass


func exit() -> void:
	pass


## Return a state name to transition, or &"" to stay.
func update(_delta: float) -> StringName:
	return &""


func physics_update(_delta: float) -> StringName:
	return &""
