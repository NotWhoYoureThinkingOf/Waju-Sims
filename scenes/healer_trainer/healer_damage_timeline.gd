# Healer Trainer: the party damage for the Kefka Says phase.
#
# It reads the existing P4 timeline and the existing mechanic areas. It never changes them.
# These are first-draft numbers. Edit them freely, or change "Damage Scale" on the
# PartyHealthController node in the Inspector to make everything harder or easier.
#
# EVENTS = raidwide hits that land on the whole party at a set time.
#   time   = seconds on the P4 timeline when the hit lands
#   label  = name shown in the Output panel
#   damage = HP every party member loses, BEFORE mitigation and before "Damage Scale"
#   effect = (optional) the screen effect that plays with the hit:
#            "cosmic" (Grand Cross), "chaos_1" or "chaos_2" (Chaos's first and second cast,
#            which are Inferno's fire or Tsunami's water depending on the order the sim picked),
#            "flood" (Flood of Naughts: lasers fired from Neo Exdeath)
#
# SPELL_DAMAGE = damage to anyone standing inside a mechanic area (the same areas that
#   already add to the fail list). The key is the spell name used by the sim.
#   damage  = HP lost by each person hit, before mitigation and "Damage Scale"
#   element = (optional) "ice" or "lightning". Being hit by BOTH within a moment is lethal.

extends RefCounted

const EVENTS := [
	{"time": 12.4, "label": "Grand Cross", "damage": 70.0, "effect": "cosmic"},
	{"time": 17.4, "label": "Chaos (Inferno/Tsunami)", "damage": 70.0, "effect": "chaos_1"},
	{"time": 27.3, "label": "Grand Cross", "damage": 70.0, "effect": "cosmic"},
	{"time": 32.4, "label": "Chaos (Inferno/Tsunami)", "damage": 70.0, "effect": "chaos_2"},
	{"time": 42.4, "label": "Grand Cross", "damage": 70.0, "effect": "cosmic"},
	{"time": 55.0, "label": "Flood of Naughts", "damage": 70.0, "effect": "flood"},
	{"time": 81.6, "label": "Ultima Upsurge", "damage": 35.0},
	{"time": 120.3, "label": "Ultima Upsurge", "damage": 35.0},
]

const SPELL_DAMAGE := {
	# Kefka's lightning lines and ice cones
	"Mysterious Magic (Line)": {"damage": 60.0, "element": "lightning"},
	"Mysterious Magic (Cone)": {"damage": 60.0, "element": "ice"},
	"Thrumming Thunder (Line)": {"damage": 60.0, "element": "lightning"},
	"Blizzard Blowout (Cone)": {"damage": 60.0, "element": "ice"},
	"Mana Release (Line)": {"damage": 60.0, "element": "lightning"},
	"Mana Release (Cone)": {"damage": 60.0, "element": "ice"},
	# Manacharge: the stack and spread circles
	"Compressed Water": {"damage": 25.0},
	"Compressed Water (Fake)": {"damage": 25.0},
	"Forked Lightning": {"damage": 25.0},
	"Forked Lightning (Fake)": {"damage": 25.0},
	# Chaos's delayed Inferno and Tsunami circles
	"Entropy AoE (Twister)": {"damage": 35.0},
	"Entropy Donut (Twister, Fake)": {"damage": 35.0},
	"Dynamic Fluid AoE (Twister)": {"damage": 35.0},
	"Dynamic Fluid Donut (Twister, Fake)": {"damage": 35.0},
}
