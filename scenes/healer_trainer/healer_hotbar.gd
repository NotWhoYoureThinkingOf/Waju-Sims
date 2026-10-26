# Healer Trainer - Slice 12: clickable hotbar
#
# Draws every healer action as an icon on a hotbar, laid out like the game:
#   - top row    = actions on a Shift + number key
#   - middle row = actions on a Ctrl + number key
#   - bottom row = actions on a plain number key
# An action sits in the slot that matches its key, so if you change a key in the
# Escape menu the icon moves to the matching slot when you close the menu. Actions on
# other keys appear on an extra row above.
#
# Each icon shows its key (top left), its charges (bottom right) and the seconds until
# the next charge (middle). It darkens while it cannot be used, and while the global
# recast is running. Left-clicking an icon does the same as pressing its key.
#
# Icons are PNG files loaded from waju-sim/assets/healer_icons/ (see healer_icons.gd).
# An action with no icon file shows a coloured square with its short name.

extends Control

const HEALER_KEYBINDS = preload("res://scenes/healer_trainer/healer_keybinds.gd")
const ICONS = preload("res://scenes/healer_trainer/healer_icons.gd")

const SLOT_SIZE := 44.0
const SLOT_GAP := 3.0
const COLUMNS := 12
const ROWS := 3  # shift, ctrl, plain. A row above them is used for actions on other keys.

# Size of the whole hotbar, including the extra row on top.
const TOTAL_WIDTH := COLUMNS * (SLOT_SIZE + SLOT_GAP) - SLOT_GAP
const TOTAL_HEIGHT := (ROWS + 1) * (SLOT_SIZE + SLOT_GAP) - SLOT_GAP

# Which column each number key sits in (the order of the keys on a keyboard).
const KEY_COLUMNS := {
	KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_5: 4, KEY_6: 5,
	KEY_7: 6, KEY_8: 7, KEY_9: 8, KEY_0: 9, KEY_MINUS: 10, KEY_EQUAL: 11,
}

var _controller
var _control_menu: CanvasLayer
var _slots: Array = []


func setup(controller, control_menu: CanvasLayer) -> void:
	_controller = controller
	_control_menu = control_menu
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(TOTAL_WIDTH, TOTAL_HEIGHT)
	_build_frame()
	refresh()
	if _control_menu != null:
		_control_menu.visibility_changed.connect(_on_menu_visibility_changed)


func _process(_delta: float) -> void:
	for entry: Dictionary in _slots:
		var state: Dictionary = _controller.get_action_state(entry["action"])
		var cover: ColorRect = entry["cover"]
		var cooldown_label: Label = entry["cooldown"]
		var charge_label: Label = entry["charges"]

		var is_ready := bool(state["ready"])
		var gcd_left := float(state["gcd_left"])
		var recharge_left := float(state["recharge_left"])
		var charges := int(state["charges"])

		# Darken the whole icon when unusable, or part of it while the global recast runs.
		var cover_fraction := 0.0
		var cover_alpha := 0.5
		if not is_ready:
			cover_fraction = 1.0
			cover_alpha = 0.65
		elif gcd_left > 0.0:
			cover_fraction = clampf(gcd_left / float(state["gcd_total"]), 0.0, 1.0)
		cover.visible = cover_fraction > 0.0
		cover.size = Vector2(SLOT_SIZE, SLOT_SIZE * cover_fraction)
		cover.color = Color(0.0, 0.0, 0.0, cover_alpha)

		cooldown_label.text = str(int(ceil(recharge_left))) if recharge_left > 0.0 else ""
		charge_label.text = str(charges) if charges >= 0 else ""


# Rebuilds the icons so they match the keys currently saved.
func refresh() -> void:
	for entry: Dictionary in _slots:
		var slot: Control = entry["slot"]
		slot.queue_free()
	_slots.clear()
	var keybinds: Dictionary = SavedVariables.get_keybinds()
	var extra_column := 0
	for action: Dictionary in HEALER_KEYBINDS.ACTIONS:
		var code: int = keybinds.get(action["id"], 0)
		var cell := _cell_for(code)
		if cell.x < 0:
			cell = Vector2i(mini(extra_column, COLUMNS - 1), -1)
			extra_column += 1
		_create_slot(action, code, cell)


func _on_menu_visibility_changed() -> void:
	if not _control_menu.visible:
		refresh()


func _on_slot_gui_input(event: InputEvent, action: Dictionary) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return
	if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_controller.use_action(action)


func _build_frame() -> void:
	# Faint empty slots, like an empty hotbar in the game. The extra row on top stays empty
	# unless an action is on a key that does not fit the grid.
	for row in range(ROWS):
		for column in range(COLUMNS):
			var empty := Panel.new()
			empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
			empty.position = Vector2(column * (SLOT_SIZE + SLOT_GAP), (row + 1) * (SLOT_SIZE + SLOT_GAP))
			empty.size = Vector2(SLOT_SIZE, SLOT_SIZE)
			empty.add_theme_stylebox_override("panel", _make_style(Color(0.08, 0.08, 0.10, 0.35), 0.12))
			add_child(empty)


func _create_slot(action: Dictionary, code: int, cell: Vector2i) -> void:
	var slot := Panel.new()
	slot.mouse_filter = Control.MOUSE_FILTER_STOP
	slot.position = Vector2(cell.x * (SLOT_SIZE + SLOT_GAP), (cell.y + 1) * (SLOT_SIZE + SLOT_GAP))
	slot.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	slot.add_theme_stylebox_override("panel", _make_style(_slot_color(action), 0.55))
	slot.gui_input.connect(_on_slot_gui_input.bind(action))
	add_child(slot)

	# The icon picture. Without a PNG file, a short name on one line is shown instead.
	var icon: Texture2D = ICONS.get_icon(str(action["id"]))
	if icon != null:
		var picture := TextureRect.new()
		picture.texture = icon
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_SCALE
		slot.add_child(picture)
		picture.position = Vector2(1.0, 1.0)
		picture.size = Vector2(SLOT_SIZE - 2.0, SLOT_SIZE - 2.0)
	else:
		var name_label := _make_label(str(action.get("short", action["label"])), 9, Color.WHITE)
		slot.add_child(name_label)
		name_label.position = Vector2(0.0, 0.0)
		name_label.size = Vector2(SLOT_SIZE, SLOT_SIZE)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.clip_text = true

	# Darkening layer for "cannot use" and the global recast.
	var cover := ColorRect.new()
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.color = Color(0.0, 0.0, 0.0, 0.5)
	cover.visible = false
	slot.add_child(cover)

	# The key for this action, top left.
	var key_label := _make_label(_key_text(code), 10, Color(1.0, 1.0, 0.8))
	slot.add_child(key_label)
	key_label.position = Vector2(2.0, 0.0)

	# Charges, bottom right.
	var charge_label := _make_label("", 12, Color(1.0, 0.85, 0.5))
	slot.add_child(charge_label)
	charge_label.position = Vector2(SLOT_SIZE - 25.0, SLOT_SIZE - 19.0)
	charge_label.size = Vector2(22.0, 18.0)
	charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# Seconds until the next charge, in the middle.
	var cooldown_label := _make_label("", 16, Color.WHITE)
	slot.add_child(cooldown_label)
	cooldown_label.position = Vector2(0.0, 0.0)
	cooldown_label.size = Vector2(SLOT_SIZE, SLOT_SIZE)
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_slots.append({
		"action": action,
		"slot": slot,
		"cover": cover,
		"cooldown": cooldown_label,
		"charges": charge_label,
	})


# Works out which hotbar slot a key belongs in. Returns (-1, -1) if it does not fit the grid.
func _cell_for(code: int) -> Vector2i:
	if code == 0:
		return Vector2i(-1, -1)
	var modifiers := code & KEY_MODIFIER_MASK
	var base_key := code & KEY_CODE_MASK
	var row := -1
	if modifiers == KEY_MASK_SHIFT:
		row = 0
	elif modifiers == KEY_MASK_CTRL:
		row = 1
	elif modifiers == 0:
		row = 2
	if row < 0 or not KEY_COLUMNS.has(base_key):
		return Vector2i(-1, -1)
	return Vector2i(KEY_COLUMNS[base_key], row)


func _key_text(code: int) -> String:
	if code == 0:
		return ""
	return OS.get_keycode_string(code).replace("Shift+", "S+").replace("Ctrl+", "C+").replace("Alt+", "A+")


func _slot_color(action: Dictionary) -> Color:
	if str(action.get("kind", "instant")) == "mitigation":
		return Color(0.22, 0.38, 0.65)
	if not bool(action.get("gcd", true)):
		return Color(0.55, 0.42, 0.18)
	return Color(0.17, 0.52, 0.45)


func _make_style(fill: Color, border_alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.set_border_width_all(1)
	style.border_color = Color(1.0, 1.0, 1.0, border_alpha)
	style.set_corner_radius_all(4)
	return style


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label
