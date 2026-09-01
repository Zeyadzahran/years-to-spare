class_name StateMachine
extends Node
## Runs its State children. The first child is the initial state.

signal state_changed(from: StringName, to: StringName)

## Node the states operate on. Defaults to the machine's parent.
@export var host_path: NodePath

var current: State
var current_name: StringName = &""

var _states: Dictionary[StringName, State] = {}

func _ready() -> void:
	var host := get_node(host_path) if not host_path.is_empty() else get_parent()
	for child in get_children():
		if child is State:
			_states[StringName(child.name)] = child
			child.host = host
			child.machine = self
			child.setup()
	if not _states.is_empty():
		_transition_to(StringName(get_child(0).name))


func _process(delta: float) -> void:
	if current:
		travel(current.update(delta))


func _physics_process(delta: float) -> void:
	if current:
		travel(current.physics_update(delta))


func travel(to: StringName) -> void:
	if to.is_empty() or to == current_name:
		return
	if not _states.has(to):
		push_warning("StateMachine: no state named '%s'" % to)
		return
	_transition_to(to)


func _transition_to(to: StringName) -> void:
	var from := current_name
	if current:
		current.exit()
	current_name = to
	current = _states[to]
	current.enter(from)
	state_changed.emit(from, to)
