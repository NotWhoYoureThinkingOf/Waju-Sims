# Healer Trainer: the real-scale numbers for the Kefka Says phase.
#
# Everything here uses real in-game HP and damage sizes, so heals and hits work the same way
# in percentage terms as in the game. Damage is the "as you see it" damage: it already
# includes the other players' mitigation and shields. Only YOUR tools (Plenary Indulgence,
# Temperance, Divine Caress and your heals) change it from there.
#
# It reads the existing P4 timeline and the existing mechanic areas. It never changes them.
# Edit the numbers freely, or change "Damage Scale" on the PartyHealthController node in the
# Inspector to make everything harder or easier.
#
# MAX_HP = each party member's real maximum HP, by role slot.
#
# EVENTS = raidwide hits that land on the whole party at a set time.
#   time      = seconds on the P4 timeline when the hit lands
#   label     = name shown in the Output panel
#   damage    = HP every party member loses, BEFORE your own mitigation and "Damage Scale"
#   damage_by = (instead of damage) damage that depends on which Chaos attack it is
#   special   = (optional) "flood": Flood of Naughts. Everyone with Beyond Death is dropped to
#               1 HP and everyone with Allagan Field takes FLOOD_FIELD_DAMAGE.
#   effect    = (optional) the screen effect that plays with the hit:
#               "cosmic" (Grand Cross), "chaos_1" or "chaos_2" (Chaos's first and second cast,
#               which are Inferno's fire or Tsunami's water depending on the order the sim
#               picked), "flood" (Flood of Naughts: lasers fired from Neo Exdeath)
#
# SPELL_DAMAGE = damage to anyone standing inside a mechanic area (the same areas that
#   already add to the fail list). The key is the spell name used by the sim.
#   damage  = HP lost by each person hit, before your own mitigation and "Damage Scale"
#   element = (optional) "ice" or "lightning". Being hit by BOTH within a moment is lethal.
#
# Numbers marked (placeholder) have not been measured yet.

extends RefCounted

const MAX_HP := {
	"t1": 325462.0,
	"t2": 325219.0,
	"h1": 204515.0,
	"h2": 205237.0,
	"m1": 227580.0,
	"m2": 226708.0,
	"r1": 226458.0,
	"r2": 205328.0,
}

# Grand Cross, Chaos, Flood of Naughts and Ultima Upsurge are measured or set from the real
# fight. Ultima Upsurge is the damage seen with the owner's own 10% mitigation backed out.

# Damage to each person holding Allagan Field when Flood of Naughts hits.
const FLOOD_FIELD_DAMAGE := 60000.0
const EVENTS := [
	{"time": 12.4, "label": "Grand Cross", "damage": 155561.0, "effect": "cosmic"},
	{"time": 17.4, "label": "Chaos", "damage_by": {"inferno": 181822.0, "tsunami": 112360.0}, "effect": "chaos_1"},
	{"time": 27.3, "label": "Grand Cross", "damage": 140757.0, "effect": "cosmic"},
	{"time": 32.4, "label": "Chaos", "damage_by": {"inferno": 181822.0, "tsunami": 112360.0}, "effect": "chaos_2"},
	{"time": 42.4, "label": "Grand Cross", "damage": 116420.0, "effect": "cosmic"},
	{"time": 55.0, "label": "Flood of Naughts", "special": "flood", "effect": "flood"},
	# The Allagan Field debuffs run out 14 seconds after they are given (44.0 s) and burst.
	{"time": 58.0, "label": "Allagan Field burst", "damage": 30000.0},
	{"time": 81.6, "label": "Ultima Upsurge", "damage": 120001.0},
	{"time": 120.3, "label": "Ultima Upsurge", "damage": 120001.0},
]

# All of these are placeholders until they are measured.
const SPELL_DAMAGE := {
	# Kefka's lightning lines and ice cones
	"Mysterious Magic (Line)": {"damage": 125000.0, "element": "lightning"},
	"Mysterious Magic (Cone)": {"damage": 125000.0, "element": "ice"},
	"Thrumming Thunder (Line)": {"damage": 125000.0, "element": "lightning"},
	"Blizzard Blowout (Cone)": {"damage": 125000.0, "element": "ice"},
	"Mana Release (Line)": {"damage": 125000.0, "element": "lightning"},
	"Mana Release (Cone)": {"damage": 125000.0, "element": "ice"},
	# Manacharge: the stack and spread circles
	"Compressed Water": {"damage": 50000.0},
	"Compressed Water (Fake)": {"damage": 50000.0},
	"Forked Lightning": {"damage": 50000.0},
	"Forked Lightning (Fake)": {"damage": 50000.0},
	# Chaos's delayed Inferno and Tsunami circles
	"Entropy AoE (Twister)": {"damage": 70000.0},
	"Entropy Donut (Twister, Fake)": {"damage": 70000.0},
	"Dynamic Fluid AoE (Twister)": {"damage": 70000.0},
	"Dynamic Fluid Donut (Twister, Fake)": {"damage": 70000.0},
}
