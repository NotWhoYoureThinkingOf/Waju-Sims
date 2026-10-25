# Healer Trainer: loads action icons from PNG files on this computer.
#
# To give an action an icon, put a PNG named after the action's id in:
#     waju-sim/assets/healer_icons/
# for example  mit_plenary.png  or  heal_st_cast_1.png  (the id is in healer_keybinds.gd).
# That folder is inside "assets", which is kept out of Git, so the pictures stay on your
# computer. Restart the sim after adding or changing an icon.
#
# Actions without an icon file simply show their short name instead.

extends RefCounted

const FOLDER := "res://assets/healer_icons/"

static var _cache := {}


static func get_icon(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var texture: Texture2D = null
	var path := FOLDER + id + ".png"
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image != null and not image.is_empty():
			texture = ImageTexture.create_from_image(image)
	_cache[id] = texture
	return texture
