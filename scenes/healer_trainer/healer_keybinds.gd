# Healer Trainer: the list of healer actions.
#
# Every entry here automatically gets a saved keybind and a row in the Escape menu
# (only in scenes that use the healer trainer), and it also defines what the action does.
# To add another healer action later, add ONE more line to ACTIONS.
#
#   id        = name saved in the config file (must be unique, no spaces)
#   label     = text shown in the Escape menu and on the cast bar
#   default   = starting key: KEY_3 for "3", or KEY_3 | KEY_MASK_SHIFT for "Shift+3".
#               Also available: KEY_MASK_CTRL and KEY_MASK_ALT.
#               The player can change any key in the Escape menu at any time.
#   kind      = "instant" (heals right away) or "cast" (must stand still for cast_time)
#   gcd       = true if the action uses the global recast (the shared timer that stops you
#               using two GCD actions back to back). false for off-global-recast actions.
#   cast_time = seconds to cast. Use the real in-game value for casted heals. 0.0 for instant.
#   amount    = HP restored. A made-up number; it does not need to match the game.

extends RefCounted

const ACTIONS := [
	{"id": "heal_st_instant_1", "label": "Instant Heal 1 (Single)", "default": KEY_3 | KEY_MASK_SHIFT, "kind": "instant", "gcd": true, "cast_time": 0.0, "amount": 30.0},
	{"id": "heal_st_instant_2", "label": "Instant Heal 2 (Single)", "default": KEY_4 | KEY_MASK_SHIFT, "kind": "instant", "gcd": true, "cast_time": 0.0, "amount": 30.0},
	{"id": "heal_st_cast_1", "label": "Cast Heal (Single)", "default": KEY_5 | KEY_MASK_SHIFT, "kind": "cast", "gcd": true, "cast_time": 1.85, "amount": 60.0},
]
