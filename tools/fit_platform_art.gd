extends SceneTree
## The deck scenes point at platforms.png through padded regions, so the painted
## slab ends up narrower than the collision box it is supposed to represent -
## the boy stands on 190px of physics but only ~150px of visible ground. These
## rects are the tight alpha bounds of the three plates, measured off the sheet,
## so art width and walking surface finally agree.
const FITS := {
	"res://src/world/platform.tscn": Rect2(430, 56, 677, 260),
	"res://src/world/blink_platform.tscn": Rect2(430, 56, 677, 260),
	"res://src/world/moving_platform.tscn": Rect2(190, 383, 1153, 256),
	"res://src/world/falling_platform.tscn": Rect2(26, 701, 1484, 243),
}


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	for path: String in FITS:
		var scene := load(path) as PackedScene
		var root := scene.instantiate()
		var art := root.get_node("Art") as Sprite2D
		var atlas := art.texture as AtlasTexture
		assert(atlas != null, "%s does not use an AtlasTexture" % path)
		atlas.region = FITS[path]
		var packed := PackedScene.new()
		assert(packed.pack(root) == OK)
		assert(ResourceSaver.save(packed, path) == OK)
		print("FITTED %s -> %s" % [path.get_file(), FITS[path]])
		root.free()
	quit()
