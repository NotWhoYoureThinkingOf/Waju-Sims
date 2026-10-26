# Healer Trainer - Slice 13: buff bar
#
# A row of icons for the buffs currently on you, like the debuff bar but for good effects.
# Each icon has the seconds remaining underneath. For now it shows the damage reduction
# from Plenary Indulgence and Temperance, using the same icon as the hotbar.
#
# Move and resize it with the sim's Move UI key (Alt), like the other HUD pieces.

extends HBoxContainer

const ICONS = preload("res://scenes/healer_trainer/healer_icons.gd")

const ICON_SIZE := 36.0

var _controller
var _entries := {}


func setup(controller) -> void:
	_controller = controller
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	# A minimum size so there is something to grab when no buffs are active.
	custom_minimum_size = Vector2(130.0, ICON_SIZE + 18.0)


func _process(_delta: float) -> void:
	var seen := {}
	for buff: Dictionary in _controller.get_active_buffs():
		var id := str(buff["id"])
		seen[id] = true
		if not _entries.has(id):
			_entries[id] = _create_entry(id, str(buff["label"]))
		var time_label: Label = _entries[id]["time"]
		time_label.text = _format_time(float(buff["left"]))
	for id: String in _entries.keys():
		if not seen.has(id):
			var box: Control = _entries[id]["box"]
			box.queue_free()
			_entries.erase(id)


func _create_entry(id: String, label_text: String) -> Dictionary:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	add_child(box)

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(holder)

	var icon: Texture2D = ICONS.get_icon(id)
	if icon != null:
		var picture := TextureRect.new()
		picture.texture = icon
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_SCALE
		holder.add_child(picture)
		picture.position = Vector2(0.0, 0.0)
		picture.size = Vector2(ICON_SIZE, ICON_SIZE)
	else:
		# No icon file yet: a plain blue square with the first letters of the name.
		var panel := Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.22, 0.38, 0.65)
		style.set_border_width_all(1)
		style.border_color = Color(1.0, 1.0, 1.0, 0.55)
		style.set_corner_radius_all(4)
		panel.add_theme_stylebox_override("panel", style)
		holder.add_child(panel)
		panel.position = Vector2(0.0, 0.0)
		panel.size = Vector2(ICON_SIZE, ICON_SIZE)
		var name_label := _make_label(label_text.substr(0, 4), 10, Color.WHITE)
		panel.add_child(name_label)
		name_label.position = Vector2(0.0, 0.0)
		name_label.size = Vector2(ICON_SIZE, ICON_SIZE)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var time_label := _make_label("", 12, Color.WHITE)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(time_label)
	return {"box": box, "time": time_label}


func _format_time(seconds: float) -> String:
	if seconds >= 60.0:
		return "%dm" % int(seconds / 60.0)
	return str(int(ceil(seconds)))


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label
