# Healer Trainer - Slice 25: ground-targeted heals (Asylum)
#
# How it plays, like the game:
#   1. Press the Asylum key. "GROUND TARGETING MODE" appears and a gold ring follows the
#      mouse across the floor.
#   2. Press the key again (or left-click) to put Asylum down where the ring is. The
#      cooldown starts then.
#   3. A bubble marks the spot. Every few seconds, everyone standing inside it is healed.
# Opening the Escape menu or starting a cast cancels the targeting.
#
# The size is "Asylum Radius" on the HealerActionController node in the Inspector.

extends Node

## Sent when Asylum is put down, so the cooldown can start.
signal placed(action: Dictionary)

var radius := 11.0
var controller
var control_menu: CanvasLayer

var _targeting := false
var _action: Dictionary = {}
var _indicator: Node3D
var _label_layer: CanvasLayer
var _last_point := Vector3.ZERO
var _have_point := false
var _areas: Array = []


func _ready() -> void:
	_label_layer = CanvasLayer.new()
	_label_layer.layer = 51
	_label_layer.visible = false
	add_child(_label_layer)
	var label := Label.new()
	label.text = "GROUND TARGETING MODE"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label_layer.add_child(label)
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.offset_left = -300.0
	label.offset_right = 300.0
	label.offset_top = 40.0
	label.offset_bottom = 80.0


func is_targeting() -> bool:
	return _targeting


func start(action: Dictionary) -> void:
	_action = action
	_targeting = true
	_have_point = false
	_label_layer.visible = true
	_indicator = _build_indicator()
	_indicator.visible = false
	add_child(_indicator)
	print("[HealerTrainer] %s: ground targeting. Press it again or left-click to put it down." % action["label"])


# Puts the area down where the ring is.
func confirm() -> void:
	if not _targeting:
		return
	if not _have_point:
		print("[HealerTrainer] %s: move the mouse over the floor first" % _action["label"])
		return
	_place(_last_point)
	cancel()


func cancel() -> void:
	_targeting = false
	_label_layer.visible = false
	if _indicator != null:
		_indicator.queue_free()
		_indicator = null


func _process(delta: float) -> void:
	if _targeting:
		_update_targeting()
	_tick_areas(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not _targeting:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		confirm()
		get_viewport().set_input_as_handled()


func _update_targeting() -> void:
	if control_menu != null and control_menu.visible:
		cancel()
		return
	if controller != null and controller.get("_casting") == true:
		cancel()
		return
	var point = _mouse_ground_point()
	if point == null:
		_indicator.visible = false
		return
	_last_point = point
	_have_point = true
	_indicator.visible = true
	_indicator.global_position = point


# Where the mouse is pointing on the floor, or null if it is not pointing at the floor.
func _mouse_ground_point():
	var camera := get_viewport().get_camera_3d()
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if camera == null or player == null:
		return null
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var direction := camera.project_ray_normal(mouse)
	return Plane(Vector3.UP, player.global_position.y).intersects_ray(from, direction)


func _place(point: Vector3) -> void:
	var ground: Dictionary = _action.get("ground", {})
	var bubble := _build_bubble(point)
	_areas.append({
		"center": point,
		"radius": radius,
		"amount": float(_action["amount"]),
		"duration": float(ground.get("duration", 24.0)),
		"interval": float(ground.get("interval", 3.0)),
		"next": float(ground.get("interval", 3.0)),
		"elapsed": 0.0,
		"bubble": bubble,
	})
	print("[HealerTrainer] %s put down (radius %.1f)" % [_action["label"], radius])
	placed.emit(_action)


func _tick_areas(delta: float) -> void:
	for i in range(_areas.size() - 1, -1, -1):
		var area: Dictionary = _areas[i]
		area["elapsed"] = float(area["elapsed"]) + delta
		while float(area["next"]) <= float(area["elapsed"]) + 0.0001 and float(area["next"]) <= float(area["duration"]) + 0.0001:
			area["next"] = float(area["next"]) + float(area["interval"])
			_heal_inside(area)
		if float(area["elapsed"]) >= float(area["duration"]):
			_remove_area(i)


# Heals everyone standing inside the area.
func _heal_inside(area: Dictionary) -> void:
	if controller == null:
		return
	var health = controller._get_health()
	var party_controller := get_tree().root.find_child("PartyController", true, false)
	if health == null or party_controller == null:
		return
	var center: Vector3 = area["center"]
	var party: Dictionary = party_controller.party
	var healed := 0
	for key: String in party:
		var member := party[key] as Node3D
		if member == null:
			continue
		var offset := member.global_position - center
		offset.y = 0.0
		if offset.length() > float(area["radius"]):
			continue
		var before: float = health.get_hp(key)
		health.heal(key, float(area["amount"]))
		if health.get_hp(key) > before:
			healed += 1
			controller.sparkle_at(member.global_position)
	print("[HealerTrainer] Asylum tick: healed %d party members for up to %d" % [healed, int(area["amount"])])


func _remove_area(index: int) -> void:
	var area: Dictionary = _areas[index]
	var bubble: Node3D = area["bubble"]
	_areas.remove_at(index)
	var tween := create_tween()
	tween.tween_property(bubble, "scale", Vector3(1.0, 1.0, 1.0) * 1.05, 0.4)
	tween.tween_callback(bubble.queue_free)


# The ring that follows the mouse while you choose where to put it.
func _build_indicator() -> Node3D:
	var root := Node3D.new()
	var gold := _glow_material(Color(1.0, 0.7, 0.3, 0.8))
	var faint := _glow_material(Color(1.0, 0.55, 0.2, 0.14))
	root.add_child(_ring(radius, 0.2, gold))
	root.add_child(_ring(radius * 0.45, 0.14, gold))
	root.add_child(_flat_disc(radius, faint))
	var dot_mesh := SphereMesh.new()
	dot_mesh.radius = 0.25
	dot_mesh.height = 0.5
	dot_mesh.material = _glow_material(Color(1.0, 1.0, 1.0, 1.0))
	var dot := MeshInstance3D.new()
	dot.mesh = dot_mesh
	dot.position = Vector3(0.0, 0.3, 0.0)
	root.add_child(dot)
	return root


# The bubble that marks where Asylum is, for as long as it lasts.
func _build_bubble(center: Vector3) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.global_position = center + Vector3(0.0, 0.08, 0.0)
	var fill := _glow_material(Color(0.55, 0.75, 1.0, 0.12))
	var rim := _glow_material(Color(0.8, 0.9, 1.0, 0.55))
	root.add_child(_flat_disc(radius, fill))
	root.add_child(_ring(radius, 0.18, rim))
	var pulse := create_tween().set_loops()
	pulse.tween_property(rim, "albedo_color:a", 0.25, 1.2)
	pulse.tween_property(rim, "albedo_color:a", 0.6, 1.2)
	root.tree_exiting.connect(pulse.kill)
	return root


func _ring(ring_radius: float, thickness: float, material: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(ring_radius - thickness, 0.05)
	mesh.outer_radius = ring_radius + thickness
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance


func _flat_disc(disc_radius: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = disc_radius
	mesh.bottom_radius = disc_radius
	mesh.height = 0.04
	mesh.radial_segments = 64
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	return instance


func _glow_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	return material
