# Healer Trainer - Slice 25: Asylum (ground-targeted heal)
#
# Listens for the healer keys the player set in the Escape menu (modifier
# combinations like Shift+3 work) and performs the matching action from
# healer_keybinds.gd on the party member selected in the party list:
#   - "instant" actions heal immediately.
#   - "cast" actions show a cast bar, and heal when the cast finishes. Moving,
#     jumping or dashing while casting interrupts it, as in the game.
#   - Slidecasting: moving during the last part of a cast (20% by default) does not
#     interrupt it. A small marker on the cast bar shows where that part begins.
#   - The hotbar (healer_hotbar.gd) shows every action in the slot that matches its key
#     (plain keys on the bottom row, Ctrl on the middle row, Shift on the top row). It can
#     be clicked with the mouse, and shows charges and cooldown seconds on each icon.
#   - Mitigation abilities reduce all damage the party takes for a while. Active ones
#     are listed under the bars with the time they have left.
#   - Lilies: spells with "uses" spend a shared resource (one lily each). Lilies come
#     back one at a time and are shown at the top of the list under the bars.
#   - Actions with gcd = true share the global recast: after using one you must wait
#     "Global Recast" seconds (counted from the start of the cast) before the next.
#     A thin bar under the cast bar shows the global recast.
#   - Actions with charges (like the Shift+3 ability) hold a few charges. Each used
#     charge comes back after its own cooldown. They are listed under the bars.
#
# Turn this off by unticking "Enabled" in the Inspector.

extends Node

const HEALER_KEYBINDS = preload("res://scenes/healer_trainer/healer_keybinds.gd")
const HOTBAR = preload("res://scenes/healer_trainer/healer_hotbar.gd")
const BUFF_BAR = preload("res://scenes/healer_trainer/healer_buff_bar.gd")
const MOVABLE = preload("res://scenes/healer_trainer/healer_movable.gd")
const VISUALS = preload("res://scenes/healer_trainer/healer_visuals.gd")
const GROUND = preload("res://scenes/healer_trainer/healer_ground_heal.gd")

@export var enabled := true
## The global recast in seconds (your in-game 2.31).
@export var global_recast := 2.31
## Turn on to allow off-global abilities while a cast bar is filling.
@export var allow_abilities_while_casting := false
## Slidecasting: moving during the last part of a cast does not interrupt it.
## This is the fraction of the cast at the end that counts (0.2 = the last 20%).
@export_range(0.0, 0.5, 0.01) var slidecast_window := 0.2
## Random amount added or removed from the window on every cast, like the real game's
## inconsistency (0 = always exactly the same, which is best for repeatable practice).
@export_range(0.0, 0.2, 0.01) var slidecast_jitter := 0.0
## Show a small marker on the cast bar where the slidecast window starts.
@export var show_slidecast_marker := true
## Speed (units per second) above which the player counts as "moving".
@export var move_cancel_speed := 2.0
## Where the cast bar STARTS: space between the bottom of the screen and the bar, in pixels.
## Hold Alt in the sim to drag it somewhere else; that choice is saved.
@export var cast_bar_bottom_offset := 250.0
## Show the clickable hotbar.
@export var show_hotbar := true
## Where the hotbar STARTS: space between the bottom of the screen and the hotbar, in pixels.
@export var hotbar_bottom_offset := 8.0
## Where the hotbar STARTS: moves it left (negative) or right (positive), in pixels.
@export var hotbar_offset_x := 0.0
## Show the visual effects: Kefka's ice and lightning, the Grand Cross / Inferno / Tsunami screen
## effects, and the glow when a party-wide heal goes out. They are decoration only.
@export var show_visual_effects := true
## How strong the visual effects are. 0 = none, 1 = normal, 2 = a lot.
@export_range(0.0, 2.0, 0.05) var visual_intensity := 1.0
## Replaces quick flashing effects with a soft fade, for anyone sensitive to flashing.
@export var reduced_flash := false
## How much bigger Neo Exdeath is drawn. 1 = the sim's original size, 2 = double.
@export_range(0.5, 4.0, 0.1) var neo_scale := 2.0
## How far Neo Exdeath is moved down. Raise it if he still looks too high.
@export_range(0.0, 5.0, 0.1) var neo_lower := 1.2
## How much bigger his ring of orbs is drawn. 1 = the sim's original size.
@export_range(0.5, 3.0, 0.05) var neo_ring_scale := 1.35
## How big Asylum is (its radius, in game units). The default is roughly half the arena across.
## Change it if it does not feel right, then run the sim again.
@export_range(2.0, 30.0, 0.5) var asylum_radius := 11.0
## Show the buff bar (damage reduction effects on you, with time left).
@export var show_buff_bar := true
## Where the buff bar STARTS: 0 to 1 across the screen, and 0 to 1 down the screen.
@export_range(0.0, 1.0, 0.005) var buff_bar_anchor_x := 0.576
@export_range(0.0, 1.0, 0.005) var buff_bar_anchor_y := 0.50

var _control_menu: CanvasLayer
var _hotbar
var _visuals
var _ground
var _buff_bar
var _health: PartyHealthController
var _player: CharacterBody3D
var _last_pos := Vector3.ZERO
var _have_last_pos := false
var _moving := false

var _casting := false
var _cast_action: Dictionary = {}
var _cast_target := ""
var _cast_elapsed := 0.0
var _cast_duration := 0.0
var _flash_left := 0.0
var _slide_time := 0.0
var _slide_reported := false
var _gcd_left := 0.0
var _charges := {}
var _recharge := {}
var _pool := {}
var _pool_timer := {}

var _bar_layer: Control
var _bar_label: Label
var _bar_progress: ProgressBar
var _slide_marker: ColorRect
var _gcd_layer: Control
var _gcd_progress: ProgressBar
var _cd_label: Label


func _enter_tree() -> void:
	# The Escape keybind menu looks for this group to know it should show the healer rows.
	add_to_group("healer_trainer")


func _ready() -> void:
	_control_menu = get_node_or_null("%ControlMenu") as CanvasLayer
	if not enabled:
		set_physics_process(false)
		return
	_build_cast_bar()
	_build_cooldown_label()
	_init_charges()
	if show_hotbar:
		_hotbar = HOTBAR.new()
		_hotbar.setup(self, _control_menu)
		_make_movable("healer_hotbar", _hotbar, "Hotbar", _hotbar_default_anchor(), 49)
	if show_buff_bar:
		_buff_bar = BUFF_BAR.new()
		_buff_bar.setup(self)
		_make_movable("healer_buff_bar", _buff_bar, "Buffs", [buff_bar_anchor_x, buff_bar_anchor_y], 48)
	_visuals = VISUALS.new()
	_visuals.effects_enabled = show_visual_effects
	_visuals.intensity = visual_intensity
	_visuals.reduced_flash = reduced_flash
	_visuals.neo_scale = neo_scale
	_visuals.neo_lower = neo_lower
	_visuals.neo_ring_scale = neo_ring_scale
	add_child(_visuals)
	_ground = GROUND.new()
	_ground.radius = asylum_radius
	_ground.controller = self
	_ground.control_menu = _control_menu
	_ground.placed.connect(_on_ground_placed)
	add_child(_ground)
	var keybinds: Dictionary = SavedVariables.get_keybinds()
	for action: Dictionary in HEALER_KEYBINDS.ACTIONS:
		var code: int = keybinds.get(action["id"], 0)
		print("[HealerTrainer] %s is bound to: %s" % [action["label"], OS.get_keycode_string(code)])


func _physics_process(delta: float) -> void:
	_update_moving(delta)
	if _gcd_left > 0.0:
		_gcd_left = maxf(_gcd_left - delta, 0.0)
		_gcd_progress.value = 1.0 - _gcd_left / global_recast
		if _gcd_left <= 0.0:
			_gcd_layer.visible = false
	_tick_charges(delta)
	_update_cooldown_label()
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_bar_layer.visible = false
	if not _casting:
		return
	if _moving:
		var time_left := _cast_duration - _cast_elapsed
		if time_left > _slide_time:
			_cancel_cast()
			return
		if not _slide_reported:
			_slide_reported = true
			print("[HealerTrainer] Slidecast: moved with %.2f s of the cast left" % time_left)
	_cast_elapsed += delta
	_bar_progress.value = clampf(_cast_elapsed / _cast_duration, 0.0, 1.0)
	if _cast_elapsed >= _cast_duration:
		_finish_cast()


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	# Same rules as the existing action bar: ignore keys while the Escape menu is open
	# or while the player is rearranging the UI.
	if _control_menu != null and _control_menu.visible:
		return
	if Global.is_moving_ui:
		return
	var key_event := event as InputEventKey
	if key_event == null:
		return
	if not key_event.pressed or key_event.echo:
		return
	var keycode: int = key_event.get_keycode_with_modifiers()
	var keybinds: Dictionary = SavedVariables.get_keybinds()
	for action: Dictionary in HEALER_KEYBINDS.ACTIONS:
		if keycode == keybinds.get(action["id"], 0):
			_on_healer_action(action)
			return


# Used by the hotbar when an icon is clicked. Follows the same rules as pressing the key.
func use_action(action: Dictionary) -> void:
	if not enabled:
		return
	if _control_menu != null and _control_menu.visible:
		return
	if Global.is_moving_ui:
		return
	_on_healer_action(action)


# Used by the buff bar: the effects currently on the party, each with "id", "label", "left".
func get_active_buffs() -> Array:
	var health := _get_health()
	if health == null:
		return []
	var buffs: Array = health.get_mitigations()
	buffs.append_array(health.get_hots(Global.player_role_key))
	return buffs


# Used by the hotbar to draw charges, cooldowns and the global recast on each icon.
func get_action_state(action: Dictionary) -> Dictionary:
	var id: String = action["id"]
	var uses_gcd: bool = action.get("gcd", true)
	var state := {
		"ready": _has_charge(action),
		"gcd_left": _gcd_left if uses_gcd else 0.0,
		"gcd_total": global_recast,
		"charges": -1,
		"recharge_left": 0.0,
	}
	if _charges.has(id):
		state["charges"] = int(_charges[id])
		if int(_charges[id]) < int(action["charges"]):
			state["recharge_left"] = _recharge_left(action)
	return state


# Asylum and other ground-targeted actions: the first press starts aiming, the second puts it
# down. The charge (and so the cooldown) is only used when it is put down.
func _use_ground_action(action: Dictionary) -> void:
	if _ground == null:
		return
	if _ground.is_targeting():
		_ground.confirm()
		return
	if _casting and not allow_abilities_while_casting:
		print("[HealerTrainer] %s: cannot use abilities while casting" % action["label"])
		return
	if not _has_charge(action):
		print("[HealerTrainer] %s: %s" % [action["label"], _charge_status(action)])
		return
	_ground.start(action)


func _on_ground_placed(action: Dictionary) -> void:
	_use_charge(action)


# Used by Asylum for the little sparkles on each person it heals.
func sparkle_at(at: Vector3) -> void:
	if _visuals != null:
		_visuals.sparkle_at(at)


func _on_healer_action(action: Dictionary) -> void:
	if str(action.get("kind", "instant")) == "ground":
		_use_ground_action(action)
		return
	# Single-target actions need a selected party member; party-wide actions do not.
	var target := ""
	if action.get("target", "single") == "single":
		target = _get_target_role_key()
		if target == "":
			print("[HealerTrainer] %s: no target selected (click a party member in the party list)" % action["label"])
			return
	if _get_health() == null:
		print("[HealerTrainer] %s: party health is not running" % action["label"])
		return
	var uses_gcd: bool = action.get("gcd", true)
	if uses_gcd and _gcd_left > 0.0:
		print("[HealerTrainer] %s: global recast not ready (%.2f s left)" % [action["label"], _gcd_left])
		return
	if not uses_gcd and _casting and not allow_abilities_while_casting:
		print("[HealerTrainer] %s: cannot use abilities while casting" % action["label"])
		return
	if not _has_charge(action):
		print("[HealerTrainer] %s: %s" % [action["label"], _charge_status(action)])
		return
	var kind: String = action.get("kind", "instant")
	if kind == "cast":
		_start_cast(action, target)
	elif kind == "mitigation":
		_apply_mitigation(action)
		_use_charge(action)
		if uses_gcd:
			_start_gcd()
	else:
		_apply_heal(action, target)
		_use_charge(action)
		if uses_gcd:
			_start_gcd()


func _apply_mitigation(action: Dictionary) -> void:
	var health := _get_health()
	if health == null:
		return
	health.add_mitigation(action["id"], action["label"], float(action["mitigation"]), float(action["duration"]))
	print("[HealerTrainer] %s: %d%% less damage taken for %.0f s" % [action["label"], int(round(float(action["mitigation"]) * 100.0)), float(action["duration"])])


func _apply_heal(action: Dictionary, target: String) -> void:
	var health := _get_health()
	if health == null:
		return
	if action.get("target", "single") == "party":
		var healed := 0
		for key: String in PartyHealthController.ROLE_KEYS:
			var hp_before: float = health.get_hp(key)
			health.heal(key, float(action["amount"]))
			if health.get_hp(key) > hp_before:
				healed += 1
		if action.has("hot"):
			var hot: Dictionary = action["hot"]
			health.add_hot_all(str(action["id"]), str(action["label"]), float(hot["amount"]), float(hot["duration"]), float(hot.get("interval", 3.0)))
		print("[HealerTrainer] %s: healed %d party members (up to +%d each)%s" % [action["label"], healed, int(action["amount"]), " and started a heal over time" if action.has("hot") else ""])
		if _visuals != null:
			_visuals.play_party_heal()
		return
	var before: float = health.get_hp(target)
	health.heal(target, float(action["amount"]))
	if action.has("hot"):
		var target_hot: Dictionary = action["hot"]
		health.add_hot(target, str(action["id"]), str(action["label"]), float(target_hot["amount"]), float(target_hot["duration"]), float(target_hot.get("interval", 3.0)))
	var after: float = health.get_hp(target)
	print("[HealerTrainer] %s on %s: %d -> %d" % [action["label"], target, int(before), int(after)])


func _start_cast(action: Dictionary, target: String) -> void:
	if _casting:
		print("[HealerTrainer] %s: already casting" % action["label"])
		return
	if _moving:
		print("[HealerTrainer] %s: cannot cast while moving" % action["label"])
		return
	if action.get("gcd", true):
		_start_gcd()
	_use_charge(action)
	_casting = true
	_cast_action = action
	_cast_target = target  # The target is locked in when the cast starts.
	_cast_elapsed = 0.0
	_cast_duration = maxf(float(action["cast_time"]), 0.01)
	var fraction := clampf(slidecast_window + randf_range(-slidecast_jitter, slidecast_jitter), 0.0, 0.5)
	_slide_time = _cast_duration * fraction
	_slide_reported = false
	_slide_marker.visible = show_slidecast_marker and slidecast_window > 0.0
	_slide_marker.position = Vector2(_bar_progress.custom_minimum_size.x * (1.0 - slidecast_window), 0.0)
	_flash_left = 0.0
	_bar_label.text = action["label"]
	_bar_progress.value = 0.0
	_bar_layer.visible = true
	print("[HealerTrainer] Casting %s on %s (%.2f s)" % [action["label"], target if target != "" else "the party", _cast_duration])


func _cancel_cast() -> void:
	print("[HealerTrainer] %s interrupted (moved)" % _cast_action["label"])
	_casting = false
	if _cast_action.get("gcd", true):
		_clear_gcd()  # An interrupted cast does not keep the global recast running.
	_bar_label.text = "Interrupted"
	_flash_left = 0.6


func _finish_cast() -> void:
	_casting = false
	_bar_layer.visible = false
	_apply_heal(_cast_action, _cast_target)


func _init_charges() -> void:
	for action: Dictionary in HEALER_KEYBINDS.ACTIONS:
		var max_charges: int = action.get("charges", 0)
		if max_charges > 0:
			_charges[action["id"]] = max_charges
			_recharge[action["id"]] = 0.0
	for id: String in HEALER_KEYBINDS.RESOURCES:
		_pool[id] = int(HEALER_KEYBINDS.RESOURCES[id]["start"])
		_pool_timer[id] = 0.0


func _has_charge(action: Dictionary) -> bool:
	var uses: Dictionary = action.get("uses", {})
	for id: String in uses:
		if int(_pool.get(id, 0)) < int(uses[id]):
			return false
	if not _charges.has(action["id"]):
		return true
	return _charges[action["id"]] > 0


# Describes why an action cannot be used right now (for the Output message).
func _charge_status(action: Dictionary) -> String:
	var uses: Dictionary = action.get("uses", {})
	for id: String in uses:
		if int(_pool.get(id, 0)) < int(uses[id]):
			var res: Dictionary = HEALER_KEYBINDS.RESOURCES[id]
			var wait := float(res["recharge"]) - float(_pool_timer[id])
			return "not enough %s, next in %.1f s" % [str(res["label"]).to_lower(), wait]
	return "no charges, next in %.1f s" % _recharge_left(action)


func _use_charge(action: Dictionary) -> void:
	var uses: Dictionary = action.get("uses", {})
	for id: String in uses:
		_pool[id] -= int(uses[id])
	if _charges.has(action["id"]):
		_charges[action["id"]] -= 1


func _recharge_left(action: Dictionary) -> float:
	var elapsed: float = _recharge.get(action["id"], 0.0)
	return float(action.get("cooldown", 0.0)) - elapsed


# Charges come back one at a time: the cooldown runs while any charge is missing.
func _tick_charges(delta: float) -> void:
	for id: String in HEALER_KEYBINDS.RESOURCES:
		var res: Dictionary = HEALER_KEYBINDS.RESOURCES[id]
		if _pool[id] >= int(res["max"]):
			_pool_timer[id] = 0.0
			continue
		_pool_timer[id] += delta
		if _pool_timer[id] >= float(res["recharge"]):
			_pool_timer[id] -= float(res["recharge"])
			_pool[id] += 1
	for action: Dictionary in HEALER_KEYBINDS.ACTIONS:
		var id: String = action["id"]
		if not _charges.has(id):
			continue
		if _charges[id] >= int(action["charges"]):
			_recharge[id] = 0.0
			continue
		_recharge[id] += delta
		var cooldown := float(action["cooldown"])
		if _recharge[id] >= cooldown:
			_recharge[id] -= cooldown
			_charges[id] += 1


func _update_cooldown_label() -> void:
	var lines: Array[String] = []
	for id: String in HEALER_KEYBINDS.RESOURCES:
		var res: Dictionary = HEALER_KEYBINDS.RESOURCES[id]
		var pool_line := "%s   %d/%d" % [res["label"], _pool[id], int(res["max"])]
		if _pool[id] < int(res["max"]):
			pool_line += "   (%.1f s)" % (float(res["recharge"]) - float(_pool_timer[id]))
		lines.append(pool_line)
	_cd_label.text = "\n".join(lines)


func _start_gcd() -> void:
	_gcd_left = global_recast
	_gcd_progress.value = 0.0
	_gcd_layer.visible = true


func _clear_gcd() -> void:
	_gcd_left = 0.0
	_gcd_layer.visible = false


func _update_moving(delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		if _player == null:
			return
	var pos := _player.global_position
	var speed := 0.0
	if _have_last_pos and delta > 0.0:
		speed = pos.distance_to(_last_pos) / delta
	_last_pos = pos
	_have_last_pos = true
	_moving = speed > move_cancel_speed


func _get_health() -> PartyHealthController:
	if _health == null:
		_health = get_tree().root.find_child("PartyHealthController", true, false) as PartyHealthController
	if _health == null or not _health.enabled:
		return null
	return _health


# The target is the party member whose focus marker is showing (set by clicking their
# row in the party list). With nobody selected, single-target heals go on yourself, like in
# the game.
func _get_target_role_key() -> String:
	var party_controller := get_node_or_null("%PartyController")
	if party_controller == null:
		return ""
	var party: Dictionary = party_controller.party
	for key: String in party:
		if party[key].focus_icon.visible:
			return key
	return Global.player_role_key


# A simple cast bar built in code, near the bottom centre of the screen.
# Wraps a HUD piece so it can be moved and resized with the Move UI key, like the sim's own.
# default_anchor = [x, y]: where the top left corner starts, as a fraction of the screen.
func _make_movable(key: String, content: Control, title: String, default_anchor: Array, layer_number: int) -> void:
	var wrapper = MOVABLE.new()
	add_child(wrapper)
	wrapper.setup(key, content, title, default_anchor, layer_number, get_node_or_null("%MoveUIResetButton"))


func _screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size


# Where the hotbar starts (bottom centre of the screen) before you move it.
func _hotbar_default_anchor() -> Array:
	var screen := _screen_size()
	var width := 12.0 * 47.0 - 3.0
	var height := 4.0 * 47.0 - 3.0
	return [
		(screen.x / 2.0 + hotbar_offset_x - width / 2.0) / screen.x,
		(screen.y - hotbar_bottom_offset - height) / screen.y,
	]


# The cast bar with the thin global recast bar under it, as one movable piece.
func _build_cast_bar() -> void:
	var group := VBoxContainer.new()
	group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_theme_constant_override("separation", 6)

	# Fixed-size holders keep the group the same size whether or not a bar is showing.
	var cast_holder := Control.new()
	cast_holder.custom_minimum_size = Vector2(300.0, 44.0)
	cast_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(cast_holder)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.position = Vector2(0.0, 0.0)
	box.size = Vector2(300.0, 44.0)
	box.visible = false
	cast_holder.add_child(box)
	_bar_layer = box

	_bar_label = Label.new()
	_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_label.add_theme_font_size_override("font_size", 18)
	_bar_label.add_theme_constant_override("outline_size", 4)
	_bar_label.add_theme_color_override("font_outline_color", Color.BLACK)
	box.add_child(_bar_label)

	_bar_progress = ProgressBar.new()
	_bar_progress.min_value = 0.0
	_bar_progress.max_value = 1.0
	_bar_progress.step = 0.001
	_bar_progress.show_percentage = false
	_bar_progress.custom_minimum_size = Vector2(300.0, 16.0)
	_bar_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_bar_progress)

	# A thin marker on the cast bar where the nominal slidecast window starts.
	_slide_marker = ColorRect.new()
	_slide_marker.color = Color(1.0, 1.0, 1.0, 0.85)
	_slide_marker.size = Vector2(2.0, 16.0)
	_slide_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide_marker.visible = false
	_bar_progress.add_child(_slide_marker)

	# The global recast bar, just under the cast bar.
	var gcd_holder := Control.new()
	gcd_holder.custom_minimum_size = Vector2(300.0, 6.0)
	gcd_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	group.add_child(gcd_holder)

	_gcd_progress = ProgressBar.new()
	_gcd_progress.min_value = 0.0
	_gcd_progress.max_value = 1.0
	_gcd_progress.step = 0.001
	_gcd_progress.show_percentage = false
	_gcd_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gcd_progress.position = Vector2(0.0, 0.0)
	_gcd_progress.size = Vector2(300.0, 6.0)
	_gcd_progress.visible = false
	gcd_holder.add_child(_gcd_progress)
	_gcd_layer = _gcd_progress

	var screen := _screen_size()
	_make_movable("healer_cast_bar", group, "Cast Bar",
		[(screen.x / 2.0 - 150.0) / screen.x, (screen.y - cast_bar_bottom_offset - 44.0) / screen.y], 50)


# A small text line showing the lilies, above the hotbar.
func _build_cooldown_label() -> void:
	_cd_label = Label.new()
	_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cd_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cd_label.custom_minimum_size = Vector2(250.0, 24.0)
	_cd_label.add_theme_font_size_override("font_size", 14)
	_cd_label.add_theme_constant_override("outline_size", 3)
	_cd_label.add_theme_color_override("font_outline_color", Color.BLACK)

	# Starts just above the hotbar, lined up with its right edge.
	var screen := _screen_size()
	var hotbar_width := 12.0 * 47.0 - 3.0
	var hotbar_height := 4.0 * 47.0 - 3.0
	_make_movable("healer_lilies", _cd_label, "Lilies",
		[(screen.x / 2.0 + hotbar_offset_x + hotbar_width / 2.0 - 250.0) / screen.x,
		(screen.y - hotbar_bottom_offset - hotbar_height - 6.0 - 24.0) / screen.y], 50)
