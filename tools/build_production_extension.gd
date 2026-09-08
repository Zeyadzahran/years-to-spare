extends SceneTree
## Produces the production greybox as a separate scene. The live extension is
## not touched until this layout passes visual and reachability review.

const OUTPUT := "res://src/levels/level_01_production_extension.tscn"
const TILESET := "res://src/world/phase1_tileset.tres"
const PLATFORM := "res://src/world/platform.tscn"
const MOVING := "res://src/world/moving_platform.tscn"
const FALLING := "res://src/world/falling_platform.tscn"
const BLINK := "res://src/world/blink_platform.tscn"
const CHECKPOINT := "res://src/world/checkpoint.tscn"
const GUARD := "res://src/actors/enemy/guard.tscn"
const GUNNER := "res://src/actors/enemy/gunner.tscn"
const WARDEN := "res://src/actors/enemy/warden.tscn"
const SAW := "res://src/world/hazards/saw.tscn"
const CRUSHER := "res://src/world/hazards/ceiling_obstacle.tscn"
const SPIKE_SMALL := "res://src/world/hazards/spike_strip_small.tscn"
const TOXIC := "res://src/world/hazards/toxic_pipe.tscn"
const PICKUP := "res://src/world/pickup.tscn"
const DECORATIONS := "res://assets/tiles/phase1/decorations.png"
const ROCKS := "res://assets/tiles/phase1/rocks-and-dirt.png"
const END_GATE_ART := "res://assets/sprites/end-gate.png"

var root_node: Node2D
var cells: Dictionary[Vector2i, bool] = {}
## Every gameplay object placed, so scenery is never scattered on top of a saw
## or stood inside a guard.
var occupied: Array[Vector2] = []


func _init() -> void:
	call_deferred(&"_build")


func _build() -> void:
	root_node = Node2D.new()
	root_node.name = "ProductionExtension"
	var terrain := TileMapLayer.new()
	terrain.name = "Terrain"
	terrain.tile_set = load(TILESET)
	terrain.position = Vector2(0, -23.333334)
	terrain.scale = Vector2.ONE / 3.0
	_add_owned(terrain, root_node)
	var platforms := _folder("Platforms")
	var checkpoints := _folder("Checkpoints")
	var hazards := _folder("Hazards")
	var enemies := _folder("Enemies")
	var pickups := _folder("Pickups")
	var gates := _folder("Gates")
	var decorations := _folder("Decorations")
	decorations.z_index = -2

	_build_act_two()
	_build_fork()
	_build_yard()
	_build_arena()
	_paint(terrain)
	_place_act_two(platforms)
	_place_fork(platforms)
	_place_yard(platforms)
	_place_checkpoints(checkpoints)
	_place_hazards(hazards)
	_place_enemies(enemies)
	_place_pickups(pickups)
	_place_fall_zones(hazards)
	_place_arena(platforms, hazards, enemies, gates)
	_place_decorations(decorations)

	var packed := PackedScene.new()
	assert(packed.pack(root_node) == OK)
	assert(ResourceSaver.save(packed, OUTPUT) == OK)
	print("PRODUCTION_GREYBOX_BUILT cells=%d" % cells.size())
	quit()


func _build_act_two() -> void:
	# Broken lift approach: a deliberate 480px gap makes the shuttle meaningful.
	_mass(98, 102, 2, 18)
	_mass(107, 111, 1, 18)

	# A readable rolling climb: never more than one tile per jump.
	_mass(114, 119, 0, 18)
	_mass(121, 126, -1, 18)
	_mass(128, 133, -2, 18)
	_mass(135, 139, 2, 18)

	# Saw Run has a continuous recovery floor. Its faster upper rhythm is made
	# from the platform art instead of a giant terrain ceiling.
	_mass(140, 166, 1, 18)


func _build_fork() -> void:
	# Long Way: the normal tiles form a broad bowl. The one-tile rise per island
	# stays fair at age 60, while distance and patrols make it the safe route.
	_mass(168, 174, 1, 18)
	_mass(176, 182, 2, 18)
	_mass(184, 190, 3, 18)
	_mass(192, 198, 4, 18)
	_mass(200, 206, 5, 18)
	_mass(208, 214, 4, 18)
	_mass(216, 222, 3, 18)
	_mass(224, 230, 2, 18)
	_mass(232, 238, 1, 18)


func _build_yard() -> void:
	_mass(240, 246, 1, 18)
	# The Drop descends in readable two-tile terraces, with moving decks offering
	# a faster line down the open seams.
	_mass(248, 253, 3, 18)
	_mass(255, 260, 5, 18)
	_mass(262, 267, 6, 18)

	# Orbit yard keeps a solid recovery floor only 120px below the machinery.
	_mass(268, 281, 7, 18)

	# A real seven-cell break makes the collapsing chain useful.
	_mass(289, 294, 4, 18)
	_mass(296, 299, 3, 18)


func _build_arena() -> void:
	_mass(300, 326, 3, 18)
	_mass(324, 326, 0, 3)


func _place_act_two(platforms: Node2D) -> void:
	# Horizontal shuttle across a gap well beyond the elder's 253px reach.
	_instance(MOVING, "BrokenLiftShuttle", Vector2(12380, 254 + _shift(12380)), platforms, {
		"size": Vector2(210, 28), "travel": Vector2(430, 0), "speed": 165.0,
		"start_at": 0.0, "one_way": true,
	})
	# Vertical freight lift, plus a slower three-step fallback around its shaft.
	_instance(MOVING, "FreightElevator", Vector2(13920, _deck_y(13920, 0.0)), platforms, {
		"size": Vector2(220, 28), "travel": Vector2(0, -360), "speed": 125.0,
		"start_at": 0.0, "one_way": false,
	})
	_instance(PLATFORM, "FreightStep01", Vector2(13770, _deck_y(13770, 120.0)), platforms, {
		"size": Vector2(170, 28), "one_way": true,
	})
	_instance(PLATFORM, "FreightStep02", Vector2(14010, 14 + _shift(14010)), platforms, {
		"size": Vector2(170, 28), "one_way": true,
	})
	_instance(PLATFORM, "FreightStep03", Vector2(14250, -106 + _shift(14250)), platforms, {
		"size": Vector2(170, 28), "one_way": true,
	})
	# A compact upper rhythm over a solid recovery floor. Every deck has a job:
	# enter, transfer, commit, and exit.
	_instance(PLATFORM, "SawRunEntryDeck", Vector2(16920, 14 + _shift(16920)), platforms, {
		"size": Vector2(185, 28), "one_way": true,
	})
	_instance(MOVING, "SawRunMovingDeck", Vector2(17280, 14 + _shift(17280)), platforms, {
		"size": Vector2(190, 28), "travel": Vector2(260, -120), "speed": 135.0,
		"start_at": 0.0, "one_way": false,
	})
	_instance(FALLING, "SawRunFallingDeck", Vector2(17700, -106 + _shift(17700)), platforms, {
		"size": Vector2(190, 28), "delay": 1.0, "fall_distance": 300.0,
	})
	_instance(PLATFORM, "SawRunExitDeck", Vector2(18120, 14 + _shift(18120)), platforms, {
		"size": Vector2(185, 28), "one_way": true,
	})


func _place_fork(platforms: Node2D) -> void:
	# The first shortcut deck is visible from the ground. No label is needed: the
	# direct line of machinery visually promises speed while the tiles roll down.
	_instance(PLATFORM, "ForkHighStep", Vector2(20160, 14 + _shift(20160)), platforms, {
		"size": Vector2(200, 28), "one_way": true,
	})
	_instance(PLATFORM, "AgeCutLink01", Vector2(20580, -106), platforms, {
		"size": Vector2(200, 28), "one_way": true,
	})

	# Age Cut: a straight, volatile platform line above the Long Way bowl.
	for data in [
		["AgeCutFall01", Vector2(21000, -106)],
		["AgeCutFall02", Vector2(22260, 14)],
		["AgeCutFall03", Vector2(23940, 14)],
	]:
		_instance(FALLING, data[0], data[1], platforms, {
			"size": Vector2(200, 28), "delay": 0.82, "fall_distance": 420.0,
		})

	for data in [
		["AgeCutBlink01", Vector2(21420, 14), 0.0],
		["AgeCutBlink03", Vector2(22680, -106), 0.64],
		["AgeCutBlink04", Vector2(23520, -106), 0.16],
		["AgeCutBlink06", Vector2(24780, 14), 0.8],
	]:
		_instance(BLINK, data[0], data[1], platforms, {
			"size": Vector2(200, 28), "phase_offset": data[2],
			"visible_time": 1.25, "hidden_time": 0.72,
		})

	# Permanent anchors divide the cut into three comfortable five-second casts.
	# Their plain silhouette also tells the player where it is safe to wait out a
	# cooldown without any tutorial text.
	_instance(PLATFORM, "AgeCutAnchor01", Vector2(21840, -106), platforms, {
		"size": Vector2(200, 28), "one_way": true,
	})
	_instance(PLATFORM, "AgeCutLink02", Vector2(23100, 14), platforms, {
		"size": Vector2(200, 28), "one_way": true,
	})
	_instance(PLATFORM, "AgeCutAnchor03", Vector2(24360, -106), platforms, {
		"size": Vector2(200, 28), "one_way": true,
	})
	_instance(PLATFORM, "AgeCutLink03", Vector2(25200, -106), platforms, {
		"size": Vector2(200, 28), "one_way": true,
	})
	_instance(MOVING, "AgeCutShuttle", Vector2(25620, 14), platforms, {
		"size": Vector2(200, 28), "travel": Vector2(420, -120), "speed": 150.0,
		"start_at": 0.0, "one_way": false,
	})
	_instance(PLATFORM, "AgeCutLink04", Vector2(26460, -106), platforms, {
		"size": Vector2(200, 28), "one_way": true,
	})
	_instance(PLATFORM, "AgeCutExit", Vector2(26880, 14), platforms, {
		"size": Vector2(200, 28), "one_way": true,
	})

	# Long Way machinery helps a slow player over the two deepest seams, but the
	# tiled route remains completely traversable without waiting for it.
	_instance(MOVING, "BowlLift", Vector2(23940, 494 + _shift(23940)), platforms, {
		"size": Vector2(190, 28), "travel": Vector2(0, -120), "speed": 105.0,
		"start_at": 0.5, "one_way": false,
	})
	_instance(PLATFORM, "BowlRest01", Vector2(23760, 374 + _shift(23760)), platforms, {
		"size": Vector2(165, 28), "one_way": true,
	})
	_instance(PLATFORM, "BowlRest02", Vector2(24000, 494 + _shift(24000)), platforms, {
		"size": Vector2(165, 28), "one_way": true,
	})
	_instance(MOVING, "LongWayShuttle", Vector2(26720, _deck_y(26720, 0.0)), platforms, {
		"size": Vector2(200, 28), "travel": Vector2(300, -120), "speed": 135.0,
		"start_at": 0.25, "one_way": false,
	})

	# Both routes approach the reunion through visible stepping stones.
	_instance(PLATFORM, "ReunionHigh01", Vector2(27600, 14 + _shift(27600)), platforms, {
		"size": Vector2(175, 28), "one_way": true,
	})
	_instance(PLATFORM, "ReunionHigh02", Vector2(27840, 14 + _shift(27840)), platforms, {
		"size": Vector2(175, 28), "one_way": true,
	})
	_instance(PLATFORM, "ReunionLow01", Vector2(27600, _deck_y(27600, 120.0)), platforms, {
		"size": Vector2(175, 28), "one_way": true,
	})
	_instance(PLATFORM, "ReunionLow02", Vector2(27840, _deck_y(27840, 120.0)), platforms, {
		"size": Vector2(175, 28), "one_way": true,
	})


func _place_yard(platforms: Node2D) -> void:
	# Three transition decks stitch the two-tile terraces together.
	for data in [
		["DropStep01", Vector2(29700, 134 + _shift(29700))],
		["DropStep02", Vector2(30540, 374 + _shift(30540))],
		["DropStep03", Vector2(31380, 614 + _shift(31380))],
	]:
		_instance(PLATFORM, data[0], data[1], platforms, {
			"size": Vector2(170, 28), "one_way": true,
		})

	# Two opposed orbits create changing transfer points over the yard void.
	_instance(MOVING, "OrbitDeckOuter", Vector2(32340, 614 + _shift(32340)), platforms, {
		"size": Vector2(205, 28), "motion_mode": 1,
		"orbit_radii": Vector2(290, 105), "orbit_speed_degrees": 48.0,
		"start_at": 0.0, "clockwise": true, "one_way": false,
	})
	_instance(MOVING, "OrbitDeckInner", Vector2(32760, 614 + _shift(32760)), platforms, {
		"size": Vector2(185, 28), "motion_mode": 1,
		"orbit_radii": Vector2(220, 90), "orbit_speed_degrees": 58.0,
		"start_at": 0.5, "clockwise": false, "one_way": false,
	})
	# Low recovery stairs make a miss cost time rather than a death.
	_instance(PLATFORM, "OrbitRecoveryIn", Vector2(31920, _deck_y(31920, 120.0)), platforms, {
		"size": Vector2(185, 28), "one_way": true,
	})
	_instance(PLATFORM, "OrbitRecoveryOut", Vector2(33480, _deck_y(33480, 120.0)), platforms, {
		"size": Vector2(185, 28), "one_way": true,
	})

	# A rising collapse chain; each deck survives slightly less time.
	for data in [
		["Collapse01", Vector2(33960, 734 + _shift(33960)), 1.0],
		["Collapse02", Vector2(34200, 614 + _shift(34200)), 0.9],
		["Collapse03", Vector2(34440, 494 + _shift(34440)), 0.8],
		["Collapse04", Vector2(34680, _deck_y(34680, 120.0)), 0.7],
	]:
		_instance(FALLING, data[0], data[1], platforms, {
			"size": Vector2(180, 28), "delay": data[2], "fall_distance": 520.0,
		})

	# Final vertical lift joins low road and firing gantry without hiding either.
	_instance(MOVING, "FiringLineLift", Vector2(35460, 494 + _shift(35460)), platforms, {
		"size": Vector2(185, 28), "travel": Vector2(0, -120), "speed": 145.0,
		"start_at": 0.0, "one_way": true,
	})


func _place_checkpoints(parent: Node2D) -> void:
	for data in [
		["ForkCheckpoint", Vector2(19800, _ground_at(19800))],
		["LongWayCheckpoint", Vector2(24720, _ground_at(24720))],
		["ReunionCheckpoint", Vector2(28320, _ground_at(28320))],
		["YardCheckpoint", Vector2(35040, _ground_at(35040))],
		["ArenaCheckpoint", Vector2(36120, _ground_at(36120))],
	]:
		_instance(CHECKPOINT, data[0], data[1], parent)


func _place_arena(platforms: Node2D, hazards: Node2D, enemies: Node2D,
		gates: Node2D) -> void:
	# Symmetrical escape steps give the melee player access to phase-two rifles
	# and create a clean arena silhouette without floating terrain slabs.
	for data in [
		["ArenaStepLeft", Vector2(36360, 254 + _shift(36360))],
		["ArenaPerchLeft", Vector2(36600, 134 + _shift(36600))],
		["ArenaStepRight", Vector2(38340, 254 + _shift(38340))],
		["ArenaPerchRight", Vector2(38580, 134 + _shift(38580))],
	]:
		_instance(PLATFORM, data[0], data[1], platforms, {
			"size": Vector2(195, 28), "one_way": true,
		})

	var left_gunner := _instance(GUNNER, "WardenGunnerLeft", Vector2(36600, 118 + _shift(36600)), enemies)
	left_gunner.add_to_group(&"warden_phase_two", true)
	var right_gunner := _instance(GUNNER, "WardenGunnerRight", Vector2(38580, 118 + _shift(38580)), enemies)
	right_gunner.add_to_group(&"warden_phase_two", true)
	for data in [
		["WardenSawLeft", Vector2(37080, 407 + _shift(37080)), 0.15],
		["WardenSawRight", Vector2(38040, 407 + _shift(38040)), 0.65],
	]:
		var blade := _instance(SAW, data[0], data[1], hazards, {
			"travel": Vector2(180, 0), "speed": 440, "start_at": data[2],
		})
		blade.add_to_group(&"warden_phase_three", true)
	_instance(WARDEN, "Warden", Vector2(37560, _ground_at(37560)), enemies)

	# The supplied gate art becomes the arena's destination landmark. Victory is
	# still earned from the Warden, so it does not create a fake blocked route.
	var gate := Sprite2D.new()
	gate.name = "EndGateLandmark"
	gate.position = Vector2(39000, _ground_at(39000) - 171.75)
	gate.scale = Vector2.ONE * 0.25
	gate.texture = load(END_GATE_ART)
	gate.z_index = 1
	_add_owned(gate, gates)


func _place_hazards(parent: Node2D) -> void:
	# Saw Run: the ground line is dangerous but readable; the platform line
	# above it is the expressive dodge. All moving blades become harmless when
	# time is stopped.
	for data in [
		["SawRunBlade01", Vector2(17160, 145 + _shift(17160)), 180.0, 360, 0.1],
		["SawRunBlade02", Vector2(17880, 145 + _shift(17880)), 200.0, 410, 0.6],
		["SawRunBlade03", Vector2(18600, 145 + _shift(18600)), 180.0, 455, 0.3],
	]:
		_instance(SAW, data[0], data[1], parent, {
			"travel": Vector2(data[2], 0), "speed": data[3], "start_at": data[4],
		})

	# Age Cut: one freezeable threat per cluster, with permanent rest anchors
	# between them. Stopping time is spectacular and safe; expert timing remains
	# possible because none of these deal damage while frozen.
	_instance(SAW, "AgeCutBlade01", Vector2(21120, -60), parent, {
		"travel": Vector2(150, 0), "speed": 440, "start_at": 0.25,
	})
	_instance(CRUSHER, "AgeCutCrusher", Vector2(22470, -330), parent, {
		"travel": Vector2(0, 270), "speed": 260, "start_at": 0.2,
		"hurts_while_frozen": false,
	})
	_instance(SAW, "AgeCutBlade02", Vector2(24060, -60), parent, {
		"travel": Vector2(150, 0), "speed": 470, "start_at": 0.7,
	})
	# Seated on the blinking deck rather than hanging between two of them: a
	# spike strip with nothing under it reads as an art mistake, and standing
	# here while the deck is solid is the point.
	_instance(SPIKE_SMALL, "AgeCutTeeth", Vector2(24780, 0), parent)

	# Long Way hazards stay stationary and jumpable. The challenge here is the
	# patrol composition, not spending years.
	_instance(SPIKE_SMALL, "LongTeeth01", Vector2(21720, _ground_at(21720) + 24), parent)
	_instance(SPIKE_SMALL, "LongTeeth02", Vector2(25320, _ground_at(25320) + 24), parent)
	_instance(SPIKE_SMALL, "LongTeeth03", Vector2(27240, _ground_at(27240) + 24), parent)

	# Yard motion changes direction: a vertical crusher, circular decks above a
	# recoverable floor, then a collapsing ascent.
	_instance(CRUSHER, "DropCrusher", Vector2(30540, 40 + _shift(30540)), parent, {
		"travel": Vector2(0, 320), "speed": 245, "start_at": 0.55,
		"hurts_while_frozen": false,
	})
	_instance(SAW, "OrbitFloorBlade", Vector2(32400, _ground_at(32400) + 48), parent, {
		"travel": Vector2(320, 0), "speed": 390, "start_at": 0.4,
	})
	_instance(TOXIC, "OrbitLeak", Vector2(33420, _ground_at(33420)), parent)


func _place_enemies(parent: Node2D) -> void:
	# Arrival extension: three small encounters, never a crowd filling the frame.
	_instance(GUARD, "WorksGuard01", Vector2(14580, _ground_at(14580)), parent, {
		"patrol_distance": 110.0,
	})
	_instance(GUNNER, "WorksGunner01", Vector2(16260, _ground_at(16260)), parent)
	_instance(GUARD, "SawRunGuard", Vector2(19080, _ground_at(19080)), parent, {
		"patrol_distance": 95.0,
	})

	# Two riflemen on stable shortcut anchors refund part of the age cost.
	_instance(GUNNER, "AgeCutGunner01", Vector2(23100, -2), parent)
	_instance(GUNNER, "AgeCutGunner02", Vector2(24360, -122), parent)

	# Long Way patrols alternate melee pressure and cover-aware rifles. Their
	# vertical separation keeps only a pair active in any camera frame.
	for data in [
		[GUARD, "LongGuard01", Vector2(20760, _ground_at(20760)), 100.0],
		[GUNNER, "LongGunner01", Vector2(21600, _ground_at(21600)), 0.0],
		[GUARD, "LongGuard02", Vector2(22740, _ground_at(22740)), 90.0],
		[GUNNER, "LongGunner02", Vector2(23700, _ground_at(23700)), 0.0],
		[GUARD, "LongGuard03", Vector2(24660, _ground_at(24660)), 105.0],
		[GUNNER, "LongGunner03", Vector2(25620, _ground_at(25620)), 0.0],
		[GUARD, "LongGuard04", Vector2(26580, _ground_at(26580)), 95.0],
		[GUNNER, "LongGunner04", Vector2(27540, _ground_at(27540)), 0.0],
	]:
		var props := {} if data[0] == GUNNER else {"patrol_distance": data[3]}
		_instance(data[0], data[1], data[2], parent, props)

	# Yard encounters sit after traversal beats, so the player is not shot while
	# learning an unfamiliar platform cycle.
	_instance(GUARD, "DropGuard", Vector2(30120, _ground_at(30120)), parent, {
		"patrol_distance": 90.0,
	})
	_instance(GUNNER, "TerraceGunner", Vector2(30960, _ground_at(30960)), parent)
	_instance(GUARD, "OrbitGuard", Vector2(32220, _ground_at(32220)), parent, {
		"patrol_distance": 100.0,
	})
	_instance(GUNNER, "OrbitGunner", Vector2(33240, _ground_at(33240)), parent)
	_instance(GUARD, "CollapseGuard", Vector2(35040, _ground_at(35040)), parent, {
		"patrol_distance": 85.0,
	})
	_instance(GUNNER, "FiringGunner", Vector2(35880, _ground_at(35880)), parent)


func _place_pickups(parent: Node2D) -> void:
	# Figs follow pressure peaks. A healthy player can leave them and return.
	for data in [
		["SawRunFig", Vector2(19320, _ground_at(19320) - 62)],
		["LongWayFig", Vector2(24720, _ground_at(24720) - 62)],
		["ReunionFig", Vector2(28320, _ground_at(28320) - 62)],
		["OrbitFig", Vector2(33420, _ground_at(33420) - 62)],
		["CollapseFig", Vector2(35040, _ground_at(35040) - 62)],
	]:
		_instance(PICKUP, data[0], data[1], parent)


## Eleven props across 27,000px of ground is what "empty" looks like. Scenery is
## placed by walking the finished terrain instead of by listing coordinates:
## landmarks sparsely, so each stretch gets its own skyline, and clutter densely
## so no ledge reads as bare tile. Seeded, so a rebuild does not reshuffle it.
const LANDMARKS := [
	[Rect2(37, 39, 353, 591), -1],      # palm, tall
	[Rect2(400, 231, 322, 402), -1],    # palm, leaning
	[Rect2(756, 142, 307, 498), -1],    # dead tree
	[Rect2(994, 770, 418, 270), 0],     # machinery pile
	[Rect2(700, 734, 269, 299), 0],     # broken pipe
	[Rect2(45, 668, 210, 368), 0],      # cactus
]
const CLUTTER := [
	[Rect2(1129, 417, 273, 216), 0],    # bush
	[Rect2(340, 854, 322, 172), 0],     # small debris
]
## Cut from the rock sheet and kept behind the actors, so a ledge edge reads as
## rubble rather than a clean cut.
const RUBBLE := [
	Rect2(1001.0543, 584.81525, 203.16626, 141.8689),
	Rect2(727.2217, 290.783, 135.22375, 138.07138),
]


func _place_decorations(parent: Node2D) -> void:
	var tops := _surface_tiles()
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260908
	var index := 0
	var since_landmark := 5
	for tx in range(98, 327):
		if not tops.has(tx):
			since_landmark += 1
			continue
		var at := Vector2(tx * 120.0 + 60.0, float(tops[tx]) * 120.0)
		if _is_busy(at):
			continue
		since_landmark += 1
		if since_landmark >= 10 and rng.randf() < 0.6:
			since_landmark = 0
			var big: Array = LANDMARKS[rng.randi_range(0, LANDMARKS.size() - 1)]
			_prop(parent, "Landmark%02d" % index, at, big[0], DECORATIONS,
				int(big[1]), rng, 0.30, 0.38)
			index += 1
			continue
		var roll := rng.randf()
		if roll < 0.44:
			var small: Array = CLUTTER[rng.randi_range(0, CLUTTER.size() - 1)]
			_prop(parent, "Clutter%02d" % index, at, small[0], DECORATIONS,
				int(small[1]), rng, 0.24, 0.34)
			index += 1
		elif roll < 0.82:
			var rock: Rect2 = RUBBLE[rng.randi_range(0, RUBBLE.size() - 1)]
			_prop(parent, "Rubble%02d" % index, at, rock, ROCKS, -1, rng, 0.16, 0.26)
			index += 1


## Topmost solid tile per column; columns of open sky are simply absent.
func _surface_tiles() -> Dictionary[int, int]:
	var tops: Dictionary[int, int] = {}
	for cell: Vector2i in cells:
		if not tops.has(cell.x) or cell.y < tops[cell.x]:
			tops[cell.x] = cell.y
	return tops


func _is_busy(at: Vector2) -> bool:
	for taken: Vector2 in occupied:
		if absf(taken.x - at.x) < 150.0 and absf(taken.y - at.y) < 200.0:
			return true
	return false


func _prop(parent: Node2D, node_name: String, at: Vector2, region: Rect2,
		sheet: String, z: int, rng: RandomNumberGenerator,
		min_scale: float, max_scale: float) -> void:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	# Nudged off the column centre and sunk a little, so props sit in the ground
	# rather than balancing on it.
	sprite.position = at + Vector2(rng.randf_range(-34.0, 34.0), rng.randf_range(0.0, 7.0))
	var s := rng.randf_range(min_scale, max_scale)
	sprite.scale = Vector2(s, s)
	sprite.flip_h = rng.randf() < 0.5
	sprite.z_index = z
	sprite.texture = load(sheet)
	sprite.offset = Vector2(0, -region.size.y * 0.5)
	sprite.region_enabled = true
	sprite.region_rect = region
	_add_owned(sprite, parent)


func _place_fall_zones(parent: Node2D) -> void:
	_fall_zone("BrokenLiftFall", Rect2(12360, 1740, 480, 600), parent)
	_fall_zone("CollapseFall", Rect2(33840, 1740, 840, 600), parent)


## How far each authored section moved when the height profile was reshaped.
## Ground-standing actors follow the terrain through _ground_at(); decks and
## aerial hazards carry literal heights, so they are shifted by the same amount
## as the ground beneath them rather than left hanging where they were.
const SECTION_SHIFT := [
	[98, 106, 0.0],
	[107, 113, -120.0],
	[114, 120, -120.0],
	[121, 127, -120.0],
	[128, 134, -120.0],
	[135, 139, 240.0],
	[140, 167, 0.0],
	[168, 175, 0.0],
	[176, 183, 0.0],
	[184, 191, 120.0],
	[192, 199, 240.0],
	[200, 207, 360.0],
	[208, 215, 240.0],
	[216, 223, 120.0],
	[224, 231, 0.0],
	[232, 239, 0.0],
	[240, 299, 0.0],
	[300, 326, 0.0],
]


func _shift(world_x: float) -> float:
	var tx := int(floor(world_x / 120.0))
	for row: Array in SECTION_SHIFT:
		if tx >= int(row[0]) and tx <= int(row[1]):
			return float(row[2])
	return 0.0


## Centre y for a deck whose walking surface should sit `above` pixels over the
## ground beneath it. Decks were authored with literal heights, so wherever the
## terrain sat higher than the author assumed they ended up flush with it - a
## platform level with the floor is scenery, not a platform.
func _deck_y(world_x: float, above: float, height: float = 28.0) -> float:
	return _ground_at(world_x) + 1.0 - above + height * 0.5


## The surface directly under a world x, read from the terrain that was just
## authored. Ground-standing objects use this instead of a hard-coded tile
## height, so reshaping the level re-seats every actor with it rather than
## leaving saws buried and guards hanging in the air.
func _ground_at(world_x: float) -> float:
	var tx := int(floor(world_x / 120.0))
	var best := 9999
	for cell: Vector2i in cells:
		if cell.x == tx and cell.y < best:
			best = cell.y
	assert(best != 9999, "No ground under x=%s (tile %d)" % [world_x, tx])
	return float(best) * 120.0 - 1.0


func _mass(left: int, right: int, top: int, bottom: int) -> void:
	assert(right - left + 1 >= 2)
	assert(bottom - top + 1 >= 2)
	for y in range(top, bottom + 1):
		for x in range(left, right + 1):
			cells[Vector2i(x, y)] = true


func _paint(layer: TileMapLayer) -> void:
	var ordered := cells.keys()
	ordered.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	for cell: Vector2i in ordered:
		var ax := 0 if not cells.has(cell + Vector2i.LEFT) else \
			2 if not cells.has(cell + Vector2i.RIGHT) else 1
		var ay := 0 if not cells.has(cell + Vector2i.UP) else \
			2 if not cells.has(cell + Vector2i.DOWN) else 1
		var alternative := 4096 if ax == 1 and posmod(cell.x + cell.y, 2) == 0 else 0
		layer.set_cell(cell, 0, Vector2i(ax, ay), alternative)


func _folder(folder_name: String) -> Node2D:
	var node := Node2D.new()
	node.name = folder_name
	_add_owned(node, root_node)
	return node


func _instance(path: String, node_name: String, at: Vector2, parent: Node,
		properties: Dictionary = {}) -> Node:
	var scene := load(path) as PackedScene
	assert(scene != null, "Missing scene: %s" % path)
	var node := scene.instantiate()
	node.name = node_name
	node.position = at
	for key: String in properties:
		node.set(key, properties[key])
	occupied.append(at)
	_add_owned(node, parent)
	return node


func _fall_zone(node_name: String, rect: Rect2, parent: Node) -> void:
	var zone := Area2D.new()
	zone.name = node_name
	zone.position = rect.position + rect.size * 0.5
	zone.collision_layer = 0
	zone.collision_mask = 2
	zone.set_script(load("res://src/world/hazards/hazard.gd"))
	zone.set("damage", 999.0)
	_add_owned(zone, parent)
	var collision := CollisionShape2D.new()
	collision.name = "Shape"
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	_add_owned(collision, zone)


func _add_owned(node: Node, parent: Node) -> void:
	parent.add_child(node)
	node.owner = root_node
