# Healer Trainer - Slice 4: casting and the global recast
#
# Listens for the healer keys the player set in the Escape menu (modifier
# combinations like Shift+3 work) and performs the matching action from
# healer_keybinds.gd on the party member selected in the party list:
#   - "instant" actions heal immediately.
#   - "cast" actions show a cast bar, and heal when the cast finishes. Moving,
#     jumping or dashing while casting interrupts it, as in the game.
#   - Actions with gcd = true share the global recast: after using one you must wait
#     "Global Recast" seconds (counted from the start of the cast) before the next.
#     A thin bar under the cast bar shows the global recast.
#
# Turn this off by unticking "Enabled" in the Inspector.

extends Node

const HEALER_KEYBINDS = preload("res://scenes/healer_trainer/healer_keybinds.gd")

@export var enabled := true
## The global recast in seconds (your in-game 2.31).
@export var global_recast := 2.31
## Speed (units per second) above which the player counts as "moving".
@export var move_cancel_speed := 2.0
## Space between the bottom of the screen and the cast bar, in pixels.
@export var cast_bar_bottom_offset := 190.0

var _control_menu: CanvasLayer
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
var _gcd_left := 0.0

var _bar_layer: CanvasLayer
var _bar_label: Label
var _bar_progress: ProgressBar
var _gcd_layer: CanvasLayer
var _gcd_progress: ProgressBar


func _enter_tree() -> void:
	# The Escape keybind menu looks for this group to know it should show the healer rows.
	add_to_group("healer_trainer")


func _ready() -> void:
	_control_menu = get_node_or_null("%ControlMenu") as CanvasLayer
	if not enabled:
		set_physics_process(false)
		return
	_build_cast_bar()
	_build_gcd_bar()
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
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_bar_layer.visible = false
	if not _casting:
		return
	if _moving:
		_cancel_cast()
		return
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


func _on_healer_action(action: Dictionary) -> void:
	var target := _get_target_role_key()
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
	var kind: String = action.get("kind", "instant")
	if kind == "cast":
		_start_cast(action, target)
	else:
		_apply_heal(action, target)
		if uses_gcd:
			_start_gcd()


func _apply_heal(action: Dictionary, target: String) -> void:
	var health := _get_health()
	if health == null:
		return
	var before: float = health.get_hp(target)
	health.heal(target, float(action["amount"]))
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
	_casting = true
	_cast_action = action
	_cast_target = target  # The target is locked in when the cast starts.
	_cast_elapsed = 0.0
	_cast_duration = maxf(float(action["cast_time"]), 0.01)
	_flash_left = 0.0
	_bar_label.text = action["label"]
	_bar_progress.value = 0.0
	_bar_layer.visible = true
	print("[HealerTrainer] Casting %s on %s (%.2f s)" % [action["label"], target, _cast_duration])


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
# row in the party list). Returns "" when nobody is selected.
func _get_target_role_key() -> String:
	var party_controller := get_node_or_null("%PartyController")
	if party_controller == null:
		return ""
	var party: Dictionary = party_controller.party
	for key: String in party:
		if party[key].focus_icon.visible:
			return key
	return ""


# A simple cast bar built in code, near the bottom centre of the screen.
func _build_cast_bar() -> void:
	_bar_layer = CanvasLayer.new()
	_bar_layer.layer = 50
	_bar_layer.visible = false
	add_child(_bar_layer)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_layer.add_child(box)
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_left = -150.0
	box.offset_right = 150.0
	box.offset_top = -(cast_bar_bottom_offset + 44.0)
	box.offset_bottom = -cast_bar_bottom_offset

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


# A thin bar just under the cast bar that fills while the global recast is running.
func _build_gcd_bar() -> void:
	_gcd_layer = CanvasLayer.new()
	_gcd_layer.layer = 50
	_gcd_layer.visible = false
	add_child(_gcd_layer)

	_gcd_progress = ProgressBar.new()
	_gcd_progress.min_value = 0.0
	_gcd_progress.max_value = 1.0
	_gcd_progress.step = 0.001
	_gcd_progress.show_percentage = false
	_gcd_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gcd_layer.add_child(_gcd_progress)
	_gcd_progress.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_gcd_progress.offset_left = -150.0
	_gcd_progress.offset_right = 150.0
	_gcd_progress.offset_top = -(cast_bar_bottom_offset - 6.0)
	_gcd_progress.offset_bottom = -(cast_bar_bottom_offset - 12.0)
