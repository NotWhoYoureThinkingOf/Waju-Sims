# Healer Trainer - Slice 2A/2B: healer keys and the instant heal
#
# Listens for the healer keys the player set in the Escape menu (modifier
# combinations like Shift+3 work). When an Instant Heal key is pressed, the party
# member selected by clicking their row in the party list is healed by a
# placeholder amount (set "Instant Heal Amount" in the Inspector).
#
# Turn this off by unticking "Enabled" in the Inspector.

extends Node

const HEALER_KEYBINDS = preload("res://scenes/healer_trainer/healer_keybinds.gd")

@export var enabled := true
@export var instant_heal_amount := 30.0

var _control_menu: CanvasLayer


func _enter_tree() -> void:
	# The Escape keybind menu looks for this group to know it should show the healer rows.
	add_to_group("healer_trainer")


func _ready() -> void:
	_control_menu = get_node_or_null("%ControlMenu") as CanvasLayer
	if not enabled:
		return
	var keybinds: Dictionary = SavedVariables.get_keybinds()
	for action: Dictionary in HEALER_KEYBINDS.ACTIONS:
		var code: int = keybinds.get(action["id"], 0)
		print("[HealerTrainer] %s is bound to: %s" % [action["label"], OS.get_keycode_string(code)])


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
	# Both Instant Heal keys currently do the same placeholder heal.
	var target := _get_target_role_key()
	if target == "":
		print("[HealerTrainer] %s: no target selected (click a party member in the party list)" % action["label"])
		return
	var health := get_tree().root.find_child("PartyHealthController", true, false) as PartyHealthController
	if health == null or not health.enabled:
		print("[HealerTrainer] %s: party health is not running" % action["label"])
		return
	var before := health.get_hp(target)
	health.heal(target, instant_heal_amount)
	var after := health.get_hp(target)
	print("[HealerTrainer] %s on %s: %d -> %d" % [action["label"], target, int(before), int(after)])


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
