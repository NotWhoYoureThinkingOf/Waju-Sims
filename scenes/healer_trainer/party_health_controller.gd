# Healer Trainer - Slice 1: party health
#
# Added on top of the existing sim. This script does NOT change the encounter
# timeline or any mechanic. It only:
#   1. gives each of the 8 party members an HP value (starts full),
#   2. shows that HP on the existing HealthBar in the party list,
#   3. applies one scripted hit when the existing P4 animation reaches
#      scripted_hit_time (default 8.0 s, the Mysterious Magic hit).
#
# Turn the whole feature off by unticking "Enabled" in the Inspector.

extends Node

class_name PartyHealthController

signal health_changed(role_key: String, current: float, maximum: float)

const ROLE_KEYS := ["t1", "t2", "h1", "h2", "m1", "m2", "r1", "r2"]
const ANIM_NODE_NAME := "P4Anim"

@export var enabled := true
@export var max_hp := 100.0
@export var scripted_hit_time := 8.0
@export var scripted_hit_damage := 40.0

var _hp := {}
var _anim: AnimationPlayer
var _party_list: PartyList
var _hit_done := false


func _ready() -> void:
	if not enabled:
		set_process(false)
		return


func _process(_delta: float) -> void:
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
	if not _hit_done and _anim.current_animation_position >= scripted_hit_time:
		_hit_done = true
		print("[HealerTrainer] Scripted hit at %.2f s" % _anim.current_animation_position)
		damage_all(scripted_hit_damage)


func reset_all() -> void:
	_hit_done = false
	for key in ROLE_KEYS:
		_hp[key] = max_hp
		_push_to_ui(key)


func damage_all(amount: float) -> void:
	for key in ROLE_KEYS:
		apply_damage(key, amount)


func apply_damage(role_key: String, amount: float) -> void:
	if not _hp.has(role_key):
		return
	_hp[role_key] = maxf(_hp[role_key] - amount, 0.0)
	_push_to_ui(role_key)


# Slice 2B: restore HP (never above max). Returns how much HP was actually restored.
func heal(role_key: String, amount: float) -> float:
	if not _hp.has(role_key):
		return 0.0
	var before: float = _hp[role_key]
	_hp[role_key] = minf(before + amount, max_hp)
	_push_to_ui(role_key)
	return _hp[role_key] - before


func get_hp(role_key: String) -> float:
	return _hp.get(role_key, 0.0)


func _push_to_ui(role_key: String) -> void:
	if _party_list != null:
		_party_list.set_member_health(role_key, _hp[role_key], max_hp)
	health_changed.emit(role_key, _hp[role_key], max_hp)
