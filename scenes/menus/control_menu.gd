# Copyright 2026
# All rights reserved.
# This file is released under "GNU General Public License 3.0".
# Please see the LICENSE file that should have been included as part of this package.

# TODO: Made keybinds exclusive.

extends CanvasLayer

enum {SPRINT, ARMS, DASH, RESET, MOVE_UI}

const PRESS_KEY_TEXT = "Press Key"
const HEALER_KEYBINDS = preload("res://scenes/healer_trainer/healer_keybinds.gd")

@onready var move_ui_key_button: Button = %MoveUIKeyButton
@onready var sprint_key_button: Button = %SprintKeyButton
@onready var arms_key_button: Button = %ArmsKeyButton
@onready var dash_key_button: Button = %DashKeyButton
@onready var reset_key_button: Button = %ResetKeyButton
@onready var buttons := [%SprintKeyButton, %ArmsKeyButton, %DashKeyButton, %ResetKeyButton, %MoveUIKeyButton]
@onready var mouse_sens_h_slider: HSlider = %MouseSensHSlider
@onready var x_sens_h_slider: HSlider = %XSensHSlider
@onready var y_sens_h_slider: HSlider = %YSensHSlider
@onready var invert_y_check_button: CheckButton = %InvertYCheckButton
@onready var party_order_margin_container: PartyOrderMenu = %PartyOrderMarginContainer
@onready var control_margin_container: MarginContainer = %ControlMarginContainer

var awaited_key: Variant
var saved_var_keys := ["ab1_sprint", "ab2_arms", "ab3_dash", "reset", "move_ui"]
var awaiting_ui := false
var encounter_menu: CanvasLayer


func _ready() -> void:
	encounter_menu = get_node_or_null("EncounterMenu")
	awaited_key = null
	# Set keybind button text.
	move_ui_key_button.set_text(OS.get_keycode_string(SavedVariables.save_data["keybinds"]["move_ui"]))
	sprint_key_button.set_text(OS.get_keycode_string(SavedVariables.save_data["keybinds"]["ab1_sprint"]))
	arms_key_button.set_text(OS.get_keycode_string(SavedVariables.save_data["keybinds"]["ab2_arms"]))
	dash_key_button.set_text(OS.get_keycode_string(SavedVariables.save_data["keybinds"]["ab3_dash"]))
	reset_key_button.set_text(OS.get_keycode_string(SavedVariables.save_data["keybinds"]["reset"]))
	# Set sliders
	mouse_sens_h_slider.set_value_no_signal(SavedVariables.save_data["settings"]["mouse_sens"])
	x_sens_h_slider.set_value_no_signal(SavedVariables.save_data["settings"]["x_sens"])
	y_sens_h_slider.set_value_no_signal(SavedVariables.save_data["settings"]["y_sens"])
	invert_y_check_button.set_pressed_no_signal(SavedVariables.save_data["settings"]["invert_y"])
	# Healer Trainer rows (does nothing in scenes without the healer trainer).
	_add_healer_keybind_rows()


func _unhandled_input(event : InputEvent) -> void:
	# Only take in keyboard inputs.
	if event is not InputEventKey:
		return
	var keycode : int = event.get_keycode_with_modifiers()
	# Handle open/closing control menu.
	if keycode == KEY_ESCAPE and event.is_pressed():
		awaited_key = null
		if encounter_menu and encounter_menu.visible:
			encounter_menu.hide_menu()
		else:
			self.visible = !self.visible
		return
	# Handle keybind input.
	if awaited_key == null:
		return
	# Healer Trainer: judge the key itself (not the key plus modifiers) so that pressing Shift
	# on its own never gets saved, which lets combos like Shift+3 be captured.
	var base_key: int = event.keycode
	if (base_key == KEY_SHIFT or base_key == KEY_CTRL or base_key == KEY_ALT) and !awaiting_ui:
		return
	GameEvents.emit_variable_saved("keybinds", saved_var_keys[awaited_key], keycode)
	buttons[awaited_key].set_text(OS.get_keycode_string(keycode))
	awaited_key = null
	awaiting_ui = false


func _on_move_ui_key_button_pressed() -> void:
	if awaited_key != null:
		return
	awaited_key = MOVE_UI
	move_ui_key_button.set_text(PRESS_KEY_TEXT)
	awaiting_ui = true


func _on_sprint_key_button_pressed() -> void:
	if awaited_key != null:
		return
	awaited_key = SPRINT
	sprint_key_button.set_text(PRESS_KEY_TEXT)


func _on_arms_key_button_pressed() -> void:
	if awaited_key != null:
		return
	awaited_key = ARMS
	arms_key_button.set_text(PRESS_KEY_TEXT)


func _on_dash_key_button_pressed() -> void:
	if awaited_key != null:
		return
	awaited_key = DASH
	dash_key_button.set_text(PRESS_KEY_TEXT)


func _on_reset_key_button_pressed() -> void:
	if awaited_key != null:
		return
	awaited_key = RESET
	reset_key_button.set_text(PRESS_KEY_TEXT)


func _on_mouse_sens_h_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		GameEvents.emit_variable_saved("settings", "mouse_sens", mouse_sens_h_slider.get_value())


func _on_x_sens_h_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		GameEvents.emit_variable_saved("settings", "x_sens", x_sens_h_slider.get_value())


func _on_y_sens_h_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		GameEvents.emit_variable_saved("settings", "y_sens", y_sens_h_slider.get_value())


func _on_invert_y_check_button_toggled(toggled_on: bool) -> void:
	GameEvents.emit_variable_saved("settings", "invert_y", toggled_on)


func _on_back_button_pressed() -> void:
	self.hide()


func _on_pt_list_button_pressed() -> void:
	control_margin_container.hide()
	party_order_margin_container.show()


# Healer Trainer: adds one keybind row per entry in healer_keybinds.gd, copying the look of
# the Sprint row. Rows only appear in scenes that contain the healer trainer.
func _add_healer_keybind_rows() -> void:
	if get_tree().get_first_node_in_group("healer_trainer") == null:
		return
	var vbox: VBoxContainer = control_margin_container.get_node_or_null("LeftButtonsVBox")
	if vbox == null:
		return
	var template: HBoxContainer = vbox.get_node_or_null("SprintContainer")
	var insert_before: Node = vbox.get_node_or_null("MouseSensContainer")
	if template == null or insert_before == null:
		return
	for action: Dictionary in HEALER_KEYBINDS.ACTIONS:
		var row := template.duplicate(0) as HBoxContainer
		row.name = "Healer_" + action["id"]
		row.unique_name_in_owner = false
		var label := row.get_node("SprintLabel") as Label
		var button := row.get_node("SprintKeyButton") as Button
		label.unique_name_in_owner = false
		button.unique_name_in_owner = false
		label.text = action["label"]
		vbox.add_child(row)
		vbox.move_child(row, insert_before.get_index())
		var index := buttons.size()
		buttons.append(button)
		saved_var_keys.append(action["id"])
		button.set_text(OS.get_keycode_string(SavedVariables.save_data["keybinds"][action["id"]]))
		button.pressed.connect(_on_healer_key_button_pressed.bind(index))


func _on_healer_key_button_pressed(index: int) -> void:
	if awaited_key != null:
		return
	awaited_key = index
	buttons[index].set_text(PRESS_KEY_TEXT)
