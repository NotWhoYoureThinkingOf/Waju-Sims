# Healer Trainer - Slice 1: party health
#
# Added on top of the existing sim. This script does NOT change the encounter
# timeline or any mechanic. It only:
#   1. gives each of the 8 party members an HP value (starts full),
#   2. shows that HP on the existing HealthBar in the party list,
#   3. applies the raidwide hits listed in healer_damage_timeline.gd when the
#      existing P4 animation reaches each one's time,
#   4. damages anyone standing in the mechanic areas listed in SPELL_DAMAGE (Kefka's ice
#      and lightning, the stack and spread circles, Chaos's circles). Being hit by both
#      ice and lightning at once is lethal.
#   5. adds a line to the fail list when a party member's HP reaches 0 (a death).
#
# Turn the whole feature off by unticking "Enabled" in the Inspector.

extends Node

class_name PartyHealthController

signal health_changed(role_key: String, current: float, maximum: float)

const ROLE_KEYS := ["t1", "t2", "h1", "h2", "m1", "m2", "r1", "r2"]
const ANIM_NODE_NAME := "P4Anim"
const TIMELINE = preload("res://scenes/healer_trainer/healer_damage_timeline.gd")
## Seconds within which being hit by both ice and lightning counts as "both".
const DOUBLE_HIT_WINDOW := 1.5

@export var enabled := true
@export var max_hp := 100.0
## Multiplies all timeline damage. 1.0 = as written, 0.5 = half, 1.5 = one and a half times.
@export var damage_scale := 1.0

var _hp := {}
var _anim: AnimationPlayer
var _party_list: PartyList
var _next_event := 0
var _dead := {}
var _element_hits := {}
var _mitigations := {}


func _ready() -> void:
	if not enabled:
		set_process(false)
		return
	# Watch for mechanic areas as the sim creates them, so we can damage whoever they hit.
	get_tree().node_added.connect(_on_node_added)


func _process(delta: float) -> void:
	_tick_mitigations(delta)
	# Find the things we need. They may not exist for the first few frames.
	if _anim == null:
		_anim = get_tree().root.find_child(ANIM_NODE_NAME, true, false) as AnimationPlayer
		if _anim == null:
			return
	if _party_list == null:
		_party_list = get_tree().get_first_node_in_group("party_list") as PartyList
		if _party_list == null:
			return
		reset_all()
		print("[HealerTrainer] Party health ready (8 members at %d HP)" % int(max_hp))

	# Only read the existing timeline. Never change it.
	if not _anim.is_playing():
		return
	var pos := _anim.current_animation_position
	while _next_event < TIMELINE.EVENTS.size() and pos >= float(TIMELINE.EVENTS[_next_event]["time"]):
		var event: Dictionary = TIMELINE.EVENTS[_next_event]
		_next_event += 1
		damage_all(float(event["damage"]) * damage_scale, str(event["label"]))


func reset_all() -> void:
	_next_event = 0
	_dead.clear()
	_element_hits.clear()
	_mitigations.clear()
	for key in ROLE_KEYS:
		_hp[key] = max_hp
		_push_to_ui(key)


func damage_all(amount: float, label := "Party hit") -> void:
	var multiplier := get_damage_multiplier()
	print("[HealerTrainer] %s: %d damage, %d%% mitigation -> %d each" % [label, int(amount), int(round((1.0 - multiplier) * 100.0)), int(amount * multiplier)])
	for key in ROLE_KEYS:
		apply_damage(key, amount)


func apply_damage(role_key: String, amount: float, ignore_mitigation := false) -> void:
	if not _hp.has(role_key) or _dead.has(role_key):
		return
	# Damage is reduced by every active mitigation (each one multiplies the damage taken).
	var multiplier := 1.0 if ignore_mitigation else get_damage_multiplier()
	_hp[role_key] = maxf(_hp[role_key] - amount * multiplier, 0.0)
	_push_to_ui(role_key)
	if _hp[role_key] <= 0.0:
		_dead[role_key] = true
		_report_death(role_key)


# Slice 2B: restore HP (never above max). Returns how much HP was actually restored.
func heal(role_key: String, amount: float) -> float:
	if not _hp.has(role_key) or _dead.has(role_key):
		return 0.0
	var before: float = _hp[role_key]
	_hp[role_key] = minf(before + amount, max_hp)
	_push_to_ui(role_key)
	return _hp[role_key] - before


# Slice 9: mitigation. Each active effect reduces damage taken by "percent" (0.10 = 10%)
# for "duration" seconds. Several effects at once multiply together.
func add_mitigation(id: String, label: String, percent: float, duration: float) -> void:
	_mitigations[id] = {"id": id, "label": label, "percent": percent, "left": duration}


func get_damage_multiplier() -> float:
	var multiplier := 1.0
	for id: String in _mitigations:
		multiplier *= 1.0 - float(_mitigations[id]["percent"])
	return multiplier


func get_mitigations() -> Array:
	return _mitigations.values()


func _tick_mitigations(delta: float) -> void:
	for id: String in _mitigations.keys():
		_mitigations[id]["left"] -= delta
		if _mitigations[id]["left"] <= 0.0:
			_mitigations.erase(id)


func _on_node_added(node: Node) -> void:
	if node is GroundMarker:
		node.collisions_checked.connect(_on_marker_checked)


# Called by the sim when a mechanic area has worked out who is standing in it.
func _on_marker_checked(bodies: Array, marker: Node3D) -> void:
	var spell := str(marker.get("spell_name"))
	if not TIMELINE.SPELL_DAMAGE.has(spell):
		return
	var info: Dictionary = TIMELINE.SPELL_DAMAGE[spell]
	for body in bodies:
		var role_key := str(body.get("role_key"))
		if _hp.has(role_key):
			_hit_by_spell(role_key, spell, info)


func _hit_by_spell(role_key: String, spell: String, info: Dictionary) -> void:
	var role_name := str(Global.ROLE_NAMES.get(role_key, role_key))
	var element := str(info.get("element", ""))
	var now := Time.get_ticks_msec() / 1000.0
	var lethal := false
	if element != "":
		var times: Dictionary = _element_hits.get(role_key, {})
		for other: String in times:
			if other != element and now - float(times[other]) <= DOUBLE_HIT_WINDOW:
				lethal = true
		times[element] = now
		_element_hits[role_key] = times
	if lethal:
		print("[HealerTrainer] %s was hit by both ice and lightning (%s): lethal" % [role_name, spell])
		apply_damage(role_key, max_hp, true)
		return
	var amount := float(info["damage"]) * damage_scale
	print("[HealerTrainer] %s hit by %s: %d damage -> %d after mitigation" % [role_name, spell, int(amount), int(amount * get_damage_multiplier())])
	apply_damage(role_key, amount)


# A death is a fail for now. Dead party members cannot be healed.
func _report_death(role_key: String) -> void:
	var role_name := str(Global.ROLE_NAMES.get(role_key, role_key))
	print("[HealerTrainer] %s died" % role_name)
	var fail_list := get_node_or_null("%FailList")
	if fail_list != null:
		fail_list.add_fail("%s died." % role_name)


func is_dead(role_key: String) -> bool:
	return _dead.has(role_key)


func get_hp(role_key: String) -> float:
	return _hp.get(role_key, 0.0)


func _push_to_ui(role_key: String) -> void:
	if _party_list != null:
		_party_list.set_member_health(role_key, _hp[role_key], max_hp)
	health_changed.emit(role_key, _hp[role_key], max_hp)
