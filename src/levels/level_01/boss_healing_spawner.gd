extends Node2D
## Keeps exactly one healing fig live in the boss room at a time, at one of a
## few predefined spots, instead of authoring several that could all be
## visible together. The fig itself is the same Pickup scene used everywhere
## else - this only ever decides *whether* one currently exists and *where*
## the next one lands; healing, visibility-at-full-health and collection are
## entirely its own, untouched logic.

const PICKUP_SCENE := preload("res://src/world/pickups/pickup.tscn")

## The boss room's two authored spots for this fig. Alternated in order
## rather than picked at random, so a run never happens to draw the same
## spot twice in a row.
@export var spawn_positions: Array[Vector2] = [Vector2(3050, 305), Vector2(3960, 295)]

var _current: Pickup = null
var _next_index := 0


func _ready() -> void:
	EventBus.player_spawned.connect(_on_player_spawned)
	EventBus.player_health_changed.connect(_on_player_health_changed)
	_on_player_spawned(get_tree().get_first_node_in_group(&"player"))


func _on_player_spawned(player: Node) -> void:
	if player == null:
		return
	var health := player.get(&"health") as HealthComponent
	if health != null:
		_on_player_health_changed(health.current, health.max_health)


func _on_player_health_changed(current: float, maximum: float) -> void:
	if current >= maximum:
		return
	# A fig already out there - visible, or mid-collection and about to free
	# itself - still covers this; _on_pickup_gone rechecks once it is gone.
	if is_instance_valid(_current):
		return
	_spawn_next()


func _spawn_next() -> void:
	var pickup := PICKUP_SCENE.instantiate() as Pickup
	add_child(pickup)
	pickup.position = spawn_positions[_next_index]
	_next_index = (_next_index + 1) % spawn_positions.size()
	pickup.tree_exited.connect(_on_pickup_gone)
	_current = pickup


## Reached either once a collected fig has actually finished freeing itself
## (queue_free waits on its own pickup sound - this and _spawn_next never
## race to have two live at once), or when the fig goes with the rest of the
## room on a level reload; get_tree() is only null for the latter, with
## nothing left worth spawning into anyway.
func _on_pickup_gone() -> void:
	_current = null
	if not is_inside_tree():
		return
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null:
		return
	var health := player.get(&"health") as HealthComponent
	if health != null:
		_on_player_health_changed(health.current, health.max_health)
