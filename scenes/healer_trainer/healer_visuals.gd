# Healer Trainer - Slice 16: 3D visual effects
#
# Purely decoration. These effects are drawn on top of the sim and never touch the
# mechanics: no collision shapes, no fail list, no damage. They exist to add to the
# visual load while you heal.
#
# For now:
#   - Kefka's lightning lines and ice cones throw 3D lightning bolts and ice crystals
#     across the area they hit, at the moment they go off.
#   - Neo Exdeath is drawn bigger (default double size).
#
# Everything is built from simple shapes in code. No game artwork is used.
#
# Settings (on the HealerActionController node in the Inspector):
#   Visual Intensity   how many bolts and crystals (0 = none, 1 = normal, 2 = a lot)
#   Reduced Flash      replaces the quick double flash of lightning with one soft fade
#   Neo Scale          how much bigger Neo Exdeath is drawn

extends Node

const TIMELINE = preload("res://scenes/healer_trainer/healer_damage_timeline.gd")

var effects_enabled := true
var intensity := 1.0
var reduced_flash := false
var neo_scale := 2.0


func _ready() -> void:
	_scale_neo()
	if effects_enabled:
		get_tree().node_added.connect(_on_node_added)


# Draws Neo Exdeath bigger. Only his body is scaled, not his rings or orbs.
func _scale_neo() -> void:
	if is_equal_approx(neo_scale, 1.0):
		return
	var neo := get_tree().root.find_child("NeoExdeath", true, false) as Node3D
	if neo == null:
		return
	var model := neo.get_node_or_null("m0418b0001") as Node3D
	if model == null:
		return
	var model_transform := model.transform
	model_transform.basis = model_transform.basis * neo_scale
	model.transform = model_transform


func _on_node_added(node: Node) -> void:
	if node is GroundMarker:
		node.collisions_checked.connect(_on_marker_checked)


# Called by the sim when a mechanic area goes off and has worked out who is standing in it.
func _on_marker_checked(_bodies: Array, marker: Node3D) -> void:
	if intensity <= 0.0:
		return
	var spell := str(marker.get("spell_name"))
	if not TIMELINE.SPELL_DAMAGE.has(spell):
		return
	var info: Dictionary = TIMELINE.SPELL_DAMAGE[spell]
	var effect := str(info.get("effect", info.get("element", "")))
	if effect == "":
		return
	var mesh_instance := marker.get("mesh_instance_3d") as MeshInstance3D
	if mesh_instance == null:
		return

	# The area's footprint, measured in the area's own space.
	var box: AABB = mesh_instance.transform * mesh_instance.get_aabb()
	var root := Node3D.new()
	add_child(root)
	root.global_transform = marker.global_transform
	var is_cone := marker is ConeAoe

	match effect:
		"lightning":
			_lightning(root, box, is_cone)
		"ice":
			_ice(root, box, is_cone)
	get_tree().create_timer(2.5).timeout.connect(root.queue_free)


# Lightning: a few jagged bolts from high above down to the ground inside the area,
# with a glow where each one lands.
func _lightning(root: Node3D, box: AABB, is_cone: bool) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.75, 0.9, 1.0, 0.95)

	var bolts := maxi(1, int(round(4.0 * intensity)))
	for i in range(bolts):
		var ground := _random_point(box, is_cone)
		var sky := ground + Vector3(randf_range(-2.0, 2.0), 14.0, randf_range(-2.0, 2.0))
		var points: Array[Vector3] = [sky]
		var pieces := 7
		for step in range(1, pieces):
			var point := sky.lerp(ground, float(step) / float(pieces))
			point.x += randf_range(-1.3, 1.3)
			point.z += randf_range(-1.3, 1.3)
			points.append(point)
		points.append(ground)
		for step in range(points.size() - 1):
			root.add_child(_segment(points[step], points[step + 1], 0.16, material))
		root.add_child(_disc(ground, 1.8, material))

	var tween := create_tween()
	if reduced_flash:
		material.albedo_color.a = 0.55
		tween.tween_property(material, "albedo_color:a", 0.0, 0.9)
	else:
		tween.tween_property(material, "albedo_color:a", 0.15, 0.06)
		tween.tween_property(material, "albedo_color:a", 1.0, 0.04)
		tween.tween_property(material, "albedo_color:a", 0.0, 0.4)


# Ice: crystals that shoot up out of the ground across the area, hold, then fade.
func _ice(root: Node3D, box: AABB, is_cone: bool) -> void:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.6, 0.85, 1.0, 0.85)
	material.emission_enabled = true
	material.emission = Color(0.35, 0.65, 1.0)
	material.emission_energy_multiplier = 0.8
	material.roughness = 0.2

	var tween := create_tween().set_parallel(true)
	var crystals := maxi(3, int(round(16.0 * intensity)))
	for i in range(crystals):
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = randf_range(0.35, 0.8)
		mesh.height = randf_range(2.0, 4.5)
		mesh.radial_segments = 5
		mesh.rings = 1
		mesh.material = material

		var crystal := MeshInstance3D.new()
		crystal.mesh = mesh
		crystal.position = Vector3(0.0, mesh.height / 2.0, 0.0)

		# The pivot sits on the ground, so the crystal grows upward from its base.
		var pivot := Node3D.new()
		pivot.position = _random_point(box, is_cone)
		pivot.rotation = Vector3(randf_range(-0.25, 0.25), randf_range(0.0, TAU), randf_range(-0.25, 0.25))
		pivot.scale = Vector3(1.0, 0.05, 1.0)
		pivot.add_child(crystal)
		root.add_child(pivot)
		tween.tween_property(pivot, "scale", Vector3.ONE, 0.18)

	tween.tween_property(material, "albedo_color:a", 0.0, 0.7).set_delay(1.0)


# A random spot on the ground inside the area. Cones are narrow near their tip.
func _random_point(box: AABB, is_cone: bool) -> Vector3:
	var z := randf_range(box.position.z, box.end.z)
	var half_width := maxf(absf(box.position.x), absf(box.end.x))
	if is_cone:
		var length := maxf(absf(box.position.z), absf(box.end.z))
		half_width *= clampf(absf(z) / maxf(length, 0.001), 0.0, 1.0)
	return Vector3(randf_range(-half_width, half_width), 0.0, z)


# A thin glowing rod between two points. Chained together they make a bolt.
func _segment(from: Vector3, to: Vector3, thickness: float, material: Material) -> MeshInstance3D:
	var direction := to - from
	var mesh := CylinderMesh.new()
	mesh.top_radius = thickness
	mesh.bottom_radius = thickness
	mesh.height = direction.length()
	mesh.radial_segments = 4
	mesh.rings = 1
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = (from + to) / 2.0
	instance.basis = Basis(Quaternion(Vector3.UP, direction.normalized()))
	return instance


# A flat glowing disc on the ground.
func _disc(at: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.04
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at + Vector3(0.0, 0.05, 0.0)
	return instance
