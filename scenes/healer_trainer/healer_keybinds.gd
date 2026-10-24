# Healer Trainer: list of configurable healer keybinds.
#
# Every entry here automatically gets:
#   - a saved setting (in the same config file as Sprint, Arm's Length, etc.),
#   - a row in the Escape keybind menu (only in scenes that use the healer trainer).
#
# To add another healer key later, add ONE more line to ACTIONS.
#
#   id      = name saved in the config file (must be unique, no spaces)
#   label   = text shown in the Escape menu
#   default = starting key. Use KEY_3 for "3", or KEY_3 | KEY_MASK_SHIFT for "Shift+3".
#             Also available: KEY_MASK_CTRL and KEY_MASK_ALT.
#
# The player can change any of these in the Escape menu at any time.

extends RefCounted

const ACTIONS := [
	{"id": "heal_st_instant_1", "label": "Instant Heal 1 (Single)", "default": KEY_3 | KEY_MASK_SHIFT},
	{"id": "heal_st_instant_2", "label": "Instant Heal 2 (Single)", "default": KEY_4 | KEY_MASK_SHIFT},
]
