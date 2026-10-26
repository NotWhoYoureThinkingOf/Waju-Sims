# Healer Trainer: loads action icons from PNG files on this computer.
#
# To give an action an icon, put a PNG named after the action's id in:
#     waju-sim/assets/healer_icons/
# for example  mit_plenary.png  or  heal_st_cast_1.png  (the id is in healer_keybinds.gd).
# That folder is inside "assets", which is kept out of Git, so the pictures stay on your
# computer. Restart the sim after adding or changing an icon.
#
# Actions without an icon file show their short name instead, and the Output panel
# says exactly which file and folder it looked for.

extends RefCounted

const FOLDER := "res://assets/healer_icons/"

static var _cache := {}
static var _reported := {}


static func get_icon(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var texture: Texture2D = null
	# The second path covers a zip that was unpacked into a folder inside the folder.
	for path: String in [FOLDER + id + ".png", FOLDER + "healer_icons/" + id + ".png"]:
		texture = _load(path)
		if texture != null:
			break
	if texture == null and not _reported.has(id):
		_reported[id] = true
		print("[HealerTrainer] No icon found for '%s'. Expected a file named %s.png in %s" % [id, id, ProjectSettings.globalize_path(FOLDER)])
	_cache[id] = texture
	return texture


static func _load(path: String) -> Texture2D:
	# First choice: read the PNG file directly.
	if FileAccess.file_exists(path):
		var image := Image.new()
		var err := image.load(path)
		if err == OK and not image.is_empty():
			return ImageTexture.create_from_image(image)
		print("[HealerTrainer] Could not read the icon file %s (error %d)" % [path, err])
	# Second choice: a picture Godot has already imported.
	if ResourceLoader.exists(path):
		var resource := load(path)
		if resource is Texture2D:
			return resource
	return null
