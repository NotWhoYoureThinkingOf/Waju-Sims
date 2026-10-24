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
#   kind      = "instant" (heals right away), "cast" (must stand still for cast_time),
#               or "mitigation" (reduces damage taken, see mitigation and duration)
#   gcd       = true if the action uses the global recast (the shared timer that stops you
#               using two GCD actions back to back). false for off-global-recast actions.
#               In the game: spells are gcd = true, abilities are gcd = false.
#   target    = (optional) "single" (the selected party member, the default) or "party"
#               (everyone in the party, no target needed).
#   mitigation = (mitigation only) damage reduction, 0.10 = 10%.
#   duration  = (mitigation only) seconds the reduction lasts.
#   uses      = (optional) shared resources the action spends, like {"lily": 1}.
#               The resources themselves are defined in RESOURCES below.
#   charges   = (optional) how many charges the action holds. Leave out for no limit.
#   cooldown  = (optional) seconds for ONE charge to come back. Used with charges.
#   cast_time = seconds to cast. Use the real in-game value for casted heals. 0.0 for instant.
#   amount    = HP restored. A made-up number; it does not need to match the game.

extends RefCounted

# Shared resources. Each one holds up to "max", starts the encounter with "start", and
# gains one back every "recharge" seconds while it is below max.
const RESOURCES := {
	"lily": {"label": "Lilies", "max": 3, "start": 3, "recharge": 20.0},
}

const ACTIONS := [
	{"id": "heal_st_instant_1", "label": "Tetragrammaton", "default": KEY_3 | KEY_MASK_SHIFT, "kind": "instant", "gcd": false, "charges": 2, "cooldown": 30.0, "cast_time": 0.0, "amount": 30.0},
	{"id": "heal_st_instant_2", "label": "Afflatus Solace", "default": KEY_4 | KEY_MASK_SHIFT, "kind": "instant", "gcd": true, "uses": {"lily": 1}, "cast_time": 0.0, "amount": 30.0},
	{"id": "heal_st_cast_1", "label": "Cure II", "default": KEY_2 | KEY_MASK_SHIFT, "kind": "cast", "gcd": true, "cast_time": 1.85, "amount": 60.0},
	{"id": "heal_aoe_instant_1", "label": "Afflatus Rapture", "default": KEY_5 | KEY_MASK_SHIFT, "kind": "instant", "gcd": true, "uses": {"lily": 1}, "target": "party", "cast_time": 0.0, "amount": 20.0},
	{"id": "heal_aoe_cast_1", "label": "Medica", "default": KEY_6 | KEY_MASK_SHIFT, "kind": "cast", "gcd": true, "target": "party", "cast_time": 1.85, "amount": 40.0},
	{"id": "mit_plenary", "label": "Plenary Indulgence", "default": KEY_7 | KEY_MASK_SHIFT, "kind": "mitigation", "gcd": false, "target": "party", "mitigation": 0.10, "duration": 10.0, "charges": 1, "cooldown": 60.0, "cast_time": 0.0, "amount": 0.0},
	{"id": "mit_temperance", "label": "Temperance", "default": KEY_8 | KEY_MASK_SHIFT, "kind": "mitigation", "gcd": false, "target": "party", "mitigation": 0.10, "duration": 20.0, "charges": 1, "cooldown": 120.0, "cast_time": 0.0, "amount": 0.0},
]
