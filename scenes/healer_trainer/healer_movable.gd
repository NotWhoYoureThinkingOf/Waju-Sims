# Healer Trainer - Slice 15: movable and resizable HUD pieces
#
# Wraps one HUD piece (the hotbar, the buff bar, the lily text, the cast bar) so it works
# like the sim's own HUD (party list, fail list, debuffs and so on):
#   - Hold the Move UI key (Alt by default). The piece shows a grey box with its name.
#   - While Alt is held: drag the box with the left mouse button to move it, and use the
#     mouse wheel over it to make it bigger or smaller.
#   - The Reset UI button (shown while Alt is held) puts it back where it started.
# The position and size are saved in the same config file as the sim's own HUD pieces.

extends CanvasLayer

const UI_SCALE_INCREMENT := 0.05
const MIN_SCALE := 0.3

var section_key := ""
var default_anchor: Array = [0.5, 0.5]
var default_scale := Vector2.ONE

var _container: MarginContainer
var _highlight: Panel
var _move_mode := false
var _is_dragging := false
var _previous_mouse := Vector2.ZERO


# content = the piece to wrap. default_anchor_fraction = [x, y] where its top left corner
# starts, as a fraction of the screen (0 to 1). reset_button = the sim's Reset UI button.
func setup(key: String, content: Control, title: String, default_anchor_fraction: Array, layer_number: int, reset_button) -> void:
	section_key = key
	default_anchor = default_anchor_fraction
	layer = layer_number

	_container = MarginContainer.new()
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.grow_horizontal = Control.GROW_DIRECTION_END
	_container.grow_vertical = Control.GROW_DIRECTION_END
	add_child(_container)
	_container.add_child(content)

	# The grey box shown while moving the HUD. It sits on top and catches the mouse.
	_highlight = Panel.new()
	_highlight.mouse_filter = Control.MOUSE_FILTER_STOP
	_highlight.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.267, 0.267, 0.267, 0.741)
	style.set_border_width_all(1)
	style.border_color = Color(0.78, 0.5, 0.36)
	_highlight.add_theme_stylebox_override("panel", style)
	_highlight.gui_input.connect(_on_highlight_gui_input)
	_container.add_child(_highlight)

	var title_label := Label.new()
	title_label.text = title
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size", 12)
	title_label.add_theme_color_override("font_outline_color", Color(0.78, 0.5, 0.36))
	title_label.add_theme_constant_override("outline_size", 3)
	title_label.position = Vector2(4.0, 2.0)
	_highlight.add_child(title_label)

	_set_anchor_fraction(default_anchor[0], default_anchor[1])
	if SavedVariables.has_data("ui_positions", section_key):
		var saved: Array = SavedVariables.get_data("ui_positions", section_key)
		_set_anchor_fraction(saved[0], saved[1])
	if SavedVariables.has_data("ui_scales", section_key):
		_container.scale = SavedVariables.config_file.get_value("ui_scales", section_key)

	set_process(false)
	GameEvents.toggle_move_ui.connect(_on_toggle_move_ui)
	if reset_button != null:
		reset_button.reset_position.connect(_reset)


func _process(_delta: float) -> void:
	if not _is_dragging:
		return
	var current := get_viewport().get_mouse_position()
	var moved := current - _previous_mouse
	var view := get_viewport().get_visible_rect().size
	_set_anchor_fraction(
		clampf(_container.anchor_left + moved.x / view.x, 0.0, 1.0),
		clampf(_container.anchor_top + moved.y / view.y, 0.0, 1.0))
	_previous_mouse = current


func _on_toggle_move_ui(is_moving: bool) -> void:
	_move_mode = is_moving
	_highlight.visible = is_moving
	set_process(is_moving)
	if not is_moving:
		_stop_dragging()


func _on_highlight_gui_input(event: InputEvent) -> void:
	if not _move_mode:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		if mouse_event.pressed:
			_is_dragging = true
			_previous_mouse = get_viewport().get_mouse_position()
			Global.is_moving_ui = true
		else:
			_stop_dragging()
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
		_change_scale(UI_SCALE_INCREMENT)
	elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
		_change_scale(-UI_SCALE_INCREMENT)
	get_viewport().set_input_as_handled()


func _stop_dragging() -> void:
	if _is_dragging:
		_is_dragging = false
		_save_position()
	# Wait a frame so the click that ended the drag is not also used by the hotbar.
	await get_tree().process_frame
	Global.is_moving_ui = false


func _change_scale(amount: float) -> void:
	var new_scale := maxf(_container.scale.x + amount, MIN_SCALE)
	_container.scale = Vector2(new_scale, new_scale)
	GameEvents.emit_variable_saved("ui_scales", section_key, _container.scale)


func _reset() -> void:
	_set_anchor_fraction(default_anchor[0], default_anchor[1])
	_container.scale = default_scale
	_save_position()
	GameEvents.emit_variable_saved("ui_scales", section_key, _container.scale)


func _save_position() -> void:
	GameEvents.emit_variable_saved("ui_positions", section_key, [_container.anchor_left, _container.anchor_top])


# Puts the top left corner of the piece at this fraction of the screen. Same method the
# sim's own HUD pieces use.
func _set_anchor_fraction(x: float, y: float) -> void:
	_container.set_anchor(SIDE_LEFT, x, true, true)
	_container.set_anchor(SIDE_RIGHT, x, true, true)
	_container.set_anchor(SIDE_TOP, y, true, true)
	_container.set_anchor(SIDE_BOTTOM, y, true, true)
