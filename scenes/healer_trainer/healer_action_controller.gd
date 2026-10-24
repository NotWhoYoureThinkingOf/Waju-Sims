# Healer Trainer - Slice 2A: healer keybinds
#
# Listens for the healer keys the player set in the Escape menu (modifier
# combinations like Shift+3 work). For now a key press only prints a line in
# the Output panel; the actual healing is added in Slice 2B.
#
# Turn this off by unticking "Enabled" in the Inspector.

extends Node

const HEALER_KEYBINDS = preload("res://scenes/healer_trainer/healer_keybinds.gd")

@export var enabled := true

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
	# Slice 2A: just prove the key arrives. Slice 2B will heal the targeted party member.
	print("[HealerTrainer] Key pressed: %s" % action["label"])
