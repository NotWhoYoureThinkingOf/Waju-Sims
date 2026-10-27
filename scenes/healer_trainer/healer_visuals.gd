# Healer Trainer - Slices 16 to 18: visual effects
#
# Purely decoration. These effects are drawn on top of the sim and never touch the
# mechanics: no collision shapes, no fail list, no damage. They exist to add to the
# visual load while you heal. Everything is built from simple shapes and shaders in
# code. No game artwork is used.
#
#   - Kefka's lightning lines and ice cones throw 3D lightning bolts and ice crystals
#     across the area they hit.
#   - Grand Cross, Inferno and Tsunami wash a see-through effect over the whole screen
#     for about three seconds. The middle stays clearer, so you never lose sight of your
#     character.
#   - Flood of Naughts fires bright lasers from Neo Exdeath at every party member.
#   - Every party-wide heal sends a glowing ring out from you, with sparkles on the party.
#   - Neo Exdeath is drawn bigger, a little lower, with a bigger ring of orbs.
#
# Settings (on the HealerActionController node in the Inspector):
#   Visual Intensity   how strong the effects are (0 = none, 1 = normal, 2 = a lot)
#   Reduced Flash      softer, slower effects with no flicker, no quick double flash
#   Neo Scale / Neo Lower / Neo Ring Scale   Neo Exdeath's size and position

extends Node

const TIMELINE = preload("res://scenes/healer_trainer/healer_damage_timeline.gd")

# How long each screen effect lasts, in seconds: fading in, holding, fading out.
const OVERLAY_TIMES := {
	"cosmic": [0.3, 1.6, 1.1],
	"fire": [0.35, 1.5, 1.1],
	"water": [0.35, 1.5, 1.1],
	"laser": [0.2, 1.9, 0.9],
}

const SHADER_START := """
shader_type canvas_item;
uniform float strength = 0.0;
uniform float calm = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amp * vnoise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return value;
}
"""

# Grand Cross: a pale lavender haze with streaks of light flying out from the middle,
# warming to orange toward the corners.
const SHADER_COSMIC := """
void fragment() {
	vec2 c = (UV - vec2(0.5)) * vec2(1.77, 1.0);
	float r = length(c);
	vec2 dir = c / max(r, 0.0001);
	float streak = pow(vnoise(dir * 5.0 + vec2(TIME * 1.2, 0.0)), 2.2);
	float haze = fbm(c * 3.0 + vec2(TIME * 0.25, -TIME * 0.15));
	float edge = smoothstep(0.15, 0.95, r);
	vec3 cool = vec3(0.82, 0.78, 1.0);
	vec3 warm = vec3(1.0, 0.55, 0.42);
	vec3 col = mix(cool, warm, smoothstep(0.55, 1.1, r));
	float pulse = mix(0.85 + 0.15 * sin(TIME * 6.0), 1.0, calm);
	float alpha = (0.10 + 0.35 * streak * edge + 0.25 * haze * edge) * strength * pulse;
	COLOR = vec4(col, clamp(alpha, 0.0, 0.7));
}
"""

# Inferno: rolling flames of red, orange and yellow, strongest around the edges.
const SHADER_FIRE := """
void fragment() {
	vec2 p = vec2(UV.x * 3.5, UV.y * 2.2 - TIME * 0.9);
	float f = fbm(p + fbm(p * 1.5 + TIME * 0.2));
	vec2 c = (UV - vec2(0.5)) * vec2(1.77, 1.0);
	float r = length(c);
	float edge = smoothstep(0.1, 0.9, r);
	float heat = f * (0.35 + 0.9 * edge);
	vec3 col = mix(vec3(0.95, 0.15, 0.05), vec3(1.0, 0.8, 0.35), smoothstep(0.35, 0.85, f));
	float glow = (1.0 - smoothstep(0.0, 0.5, r)) * 0.12;
	float flicker = mix(0.9 + 0.1 * sin(TIME * 9.0), 1.0, calm);
	float alpha = (heat * 0.85 + glow) * strength * flicker;
	COLOR = vec4(col, clamp(alpha, 0.0, 0.7));
}
"""

# Tsunami: moving blue and white water with streaks of foam, strongest around the edges.
const SHADER_WATER := """
void fragment() {
	vec2 uv = UV;
	float wave = sin(uv.x * 14.0 + TIME * 2.0 + sin(uv.y * 8.0 - TIME * 1.5) * 2.0);
	float f = fbm(vec2(uv.x * 4.0 + TIME * 0.6, uv.y * 3.0 - TIME * 0.4));
	vec2 c = (uv - vec2(0.5)) * vec2(1.77, 1.0);
	float r = length(c);
	vec2 dir = c / max(r, 0.0001);
	float streak = pow(vnoise(dir * 6.0 + vec2(TIME * 1.5, 0.0)), 2.0);
	float edge = smoothstep(0.1, 0.9, r);
	vec3 deep = vec3(0.12, 0.45, 0.95);
	vec3 foam = vec3(0.85, 0.95, 1.0);
	vec3 col = mix(deep, foam, clamp(f + streak * 0.5, 0.0, 1.0));
	float alpha = (0.10 + 0.30 * (0.5 + 0.5 * wave) * edge + 0.25 * f * edge + 0.2 * streak * edge) * strength;
	COLOR = vec4(col, clamp(alpha, 0.0, 0.7));
}
"""

# Flood of Naughts: a bright glare fanning down from the top of the screen, like light
# from the lasers.
const SHADER_LASER := """
void fragment() {
	vec2 c = (UV - vec2(0.5, 0.0)) * vec2(1.77, 1.0);
	float r = length(c);
	vec2 dir = c / max(r, 0.0001);
	float rays = pow(vnoise(vec2(dir.x * 9.0, dir.y * 3.0) + vec2(TIME * 2.0, 0.0)), 3.0);
	float glare = (1.0 - smoothstep(0.0, 0.9, r)) * 0.35;
	vec3 col = mix(vec3(0.55, 0.75, 1.0), vec3(1.0, 1.0, 1.0), clamp(rays * 1.5 + glare, 0.0, 1.0));
	float flicker = mix(0.85 + 0.15 * sin(TIME * 14.0), 1.0, calm);
	float alpha = (0.08 + 0.45 * rays + glare) * strength * flicker;
	COLOR = vec4(col, clamp(alpha, 0.0, 0.6));
}
"""

var effects_enabled := true
var intensity := 1.0
var reduced_flash := false
var neo_scale := 2.0
var neo_lower := 1.2
var neo_ring_scale := 1.35

var _overlay_rect: ColorRect
var _overlay_tween: Tween
var _shaders := {}


func _ready() -> void:
	_tune_neo()
	if not effects_enabled:
		return
	get_tree().node_added.connect(_on_node_added)
	_build_overlay()
	var health := get_tree().root.find_child("PartyHealthController", true, false)
	if health != null:
		health.raidwide_hit.connect(_on_raidwide_hit)


# Neo Exdeath: bigger body, sitting a little lower, with a bigger ring of orbs.
# Only his body and the ring are changed, so everything else about him is as before.
func _tune_neo() -> void:
	var neo := get_tree().root.find_child("NeoExdeath", true, false) as Node3D
	if neo == null:
		return
	var model := neo.get_node_or_null("m0418b0001") as Node3D
	if model != null:
		var model_transform := model.transform
		if not is_equal_approx(neo_scale, 1.0):
			model_transform.basis = model_transform.basis * neo_scale
		model_transform.origin.y -= neo_lower
		model.transform = model_transform
	var rings := neo.get_node_or_null("OrbRings") as Node3D
	if rings != null and not is_equal_approx(neo_ring_scale, 1.0):
		rings.scale = rings.scale * neo_ring_scale


# ---------------------------------------------------------------------------------
# Screen effects (Grand Cross, Inferno, Tsunami)
# ---------------------------------------------------------------------------------

func _build_overlay() -> void:
	# Drawn above the 3D world but below the HUD, so the HUD is never covered.
	var canvas := CanvasLayer.new()
	canvas.layer = 0
	add_child(canvas)
	_overlay_rect = ColorRect.new()
	_overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_rect.visible = false
	canvas.add_child(_overlay_rect)
	_overlay_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_shaders["cosmic"] = _make_shader(SHADER_COSMIC)
	_shaders["fire"] = _make_shader(SHADER_FIRE)
	_shaders["water"] = _make_shader(SHADER_WATER)
	_shaders["laser"] = _make_shader(SHADER_LASER)


func _make_shader(body: String) -> Shader:
	var shader := Shader.new()
	shader.code = SHADER_START + body
	return shader


func _on_raidwide_hit(_label: String, effect: String) -> void:
	match effect:
		"cosmic":
			play_overlay("cosmic")
		"flood":
			play_flood_lasers()
			play_overlay("laser")
		"chaos_1", "chaos_2":
			# The sim picks at random which of Chaos's two attacks comes first.
			var sequence := get_tree().root.find_child("P4Seq", true, false)
			var inferno_first := true
			if sequence != null:
				inferno_first = bool(sequence.get("inferno_first"))
			var is_inferno := (effect == "chaos_1") == inferno_first
			play_overlay("fire" if is_inferno else "water")


func play_overlay(kind: String) -> void:
	if intensity <= 0.0 or _overlay_rect == null or not _shaders.has(kind):
		return
	if _overlay_tween != null:
		_overlay_tween.kill()

	var material := ShaderMaterial.new()
	material.shader = _shaders[kind]
	material.set_shader_parameter("strength", 0.0)
	material.set_shader_parameter("calm", 1.0 if reduced_flash else 0.0)
	_overlay_rect.material = material
	_overlay_rect.visible = true

	var peak := clampf(intensity, 0.0, 1.5) * (0.6 if reduced_flash else 1.0)
	var times: Array = OVERLAY_TIMES[kind]
	var slow := 2.0 if reduced_flash else 1.0
	var set_strength := func(value: float) -> void: material.set_shader_parameter("strength", value)

	_overlay_tween = create_tween()
	_overlay_tween.tween_method(set_strength, 0.0, peak, float(times[0]) * slow)
	_overlay_tween.tween_interval(float(times[1]))
	_overlay_tween.tween_method(set_strength, peak, 0.0, float(times[2]) * slow)
	_overlay_tween.tween_callback(func() -> void: _overlay_rect.visible = false)


# ---------------------------------------------------------------------------------
# Party-wide heal: a glowing ring sent out from you, and sparkles on everyone
# ---------------------------------------------------------------------------------

func play_party_heal() -> void:
	if not effects_enabled or intensity <= 0.0:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return

	for i in range(2):
		var material := _glow_material(Color(0.55, 0.95, 1.0, 0.9 if i == 0 else 0.6))
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.92
		mesh.outer_radius = 1.0
		mesh.material = material
		var ring := MeshInstance3D.new()
		ring.mesh = mesh
		add_child(ring)
		ring.global_position = player.global_position + Vector3(0.0, 0.2 + 0.08 * i, 0.0)
		ring.scale = Vector3(0.3, 1.0, 0.3)
		var tween := create_tween().set_parallel(true)
		tween.tween_property(ring, "scale", Vector3(24.0, 1.0, 24.0), 0.7).set_delay(0.1 * i)
		tween.tween_property(material, "albedo_color:a", 0.0, 0.7).set_delay(0.1 * i)
		get_tree().create_timer(1.0).timeout.connect(ring.queue_free)

	var party_controller := get_tree().root.find_child("PartyController", true, false)
	if party_controller != null:
		var party: Dictionary = party_controller.party
		for key: String in party:
			var member := party[key] as Node3D
			if member != null:
				_sparkles(member.global_position)


func _sparkles(at: Vector3) -> void:
	var material := _glow_material(Color(0.85, 1.0, 1.0, 1.0))
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	var quad := QuadMesh.new()
	quad.size = Vector2(0.25, 0.25)
	quad.material = material

	var particles := CPUParticles3D.new()
	particles.amount = maxi(4, int(round(14.0 * intensity)))
	particles.lifetime = 0.7
	particles.one_shot = true
	particles.explosiveness = 0.85
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.7
	particles.direction = Vector3.UP
	particles.spread = 40.0
	particles.initial_velocity_min = 1.5
	particles.initial_velocity_max = 3.5
	particles.gravity = Vector3(0.0, -1.0, 0.0)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.2
	particles.mesh = quad
	add_child(particles)
	particles.global_position = at + Vector3(0.0, 0.8, 0.0)
	particles.emitting = true
	get_tree().create_timer(1.2).timeout.connect(particles.queue_free)


# Flood of Naughts: bright lasers from Neo Exdeath to every party member, about three seconds.
func play_flood_lasers() -> void:
	if not effects_enabled or intensity <= 0.0:
		return
	var neo := get_tree().root.find_child("NeoExdeath", true, false) as Node3D
	var party_controller := get_tree().root.find_child("PartyController", true, false)
	if neo == null or party_controller == null:
		return

	var origin := neo.global_position + Vector3(0.0, 4.0, 0.0)
	var core := _glow_material(Color(1.0, 1.0, 1.0, 0.0))
	var halo := _glow_material(Color(0.5, 0.75, 1.0, 0.0))
	var root := Node3D.new()
	add_child(root)

	var beams := maxi(1, int(round(2.0 * intensity)))
	if reduced_flash:
		beams = maxi(1, beams - 1)
	var party: Dictionary = party_controller.party
	for key: String in party:
		var member := party[key] as Node3D
		if member == null:
			continue
		for i in range(beams):
			var target := member.global_position + Vector3(randf_range(-1.2, 1.2), 0.9, randf_range(-1.2, 1.2))
			root.add_child(_segment(origin, target, 0.09, core))
			root.add_child(_segment(origin, target, 0.35, halo))
		root.add_child(_disc(member.global_position, 1.6, halo))

	var peak := 0.6 if reduced_flash else 1.0
	_laser_cycle(core, peak)
	_laser_cycle(halo, peak * 0.4)
	get_tree().create_timer(3.6).timeout.connect(root.queue_free)


# Fade in quickly, shimmer a little (unless Reduced Flash is on), hold, then fade out.
func _laser_cycle(material: StandardMaterial3D, peak: float) -> void:
	var tween := create_tween()
	tween.tween_property(material, "albedo_color:a", peak, 0.15)
	if not reduced_flash:
		tween.tween_property(material, "albedo_color:a", peak * 0.6, 0.12)
		tween.tween_property(material, "albedo_color:a", peak, 0.12)
		tween.tween_property(material, "albedo_color:a", peak * 0.7, 0.12)
		tween.tween_property(material, "albedo_color:a", peak, 0.12)
	tween.tween_interval(1.4)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.9)


# A glowing material that adds its light to whatever is behind it.
func _glow_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	return material


# ---------------------------------------------------------------------------------
# Kefka's ice and lightning (Slice 16)
# ---------------------------------------------------------------------------------

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
