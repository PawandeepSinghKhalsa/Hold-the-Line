extends Node

# Autoload singleton. Tracks which level the player is on and where to find
# its scene file. Also owns the player's persistent progression — best kill
# counts per level, banked kills, and purchased upgrade levels — all stored
# in user://progress.cfg via ConfigFile.

signal level_changed(level_index: int)
signal best_kills_updated(level_index: int, kills: int)
signal banked_kills_changed(kills: int)
signal upgrade_purchased(upgrade_key: String, new_level: int)
signal weapon_tier_changed(weapon_id: int, tier_index: int)
signal weapon_unlocked(weapon_id: int)
signal selected_weapon_changed(weapon_id: int)

const PROGRESS_PATH := "user://progress.cfg"

const LEVELS: Array = [
	{"name": "Level 1", "scene": "res://scenes/main.tscn"},
	{"name": "Level 2", "scene": "res://scenes/level_2.tscn"},
	{"name": "Level 3", "scene": "res://scenes/level_3.tscn"},
	{"name": "Level 4", "scene": "res://scenes/level_4.tscn"},
	{"name": "Level 5 - Twin Bosses", "scene": "res://scenes/level_5.tscn"},
	{"name": "Level 6 - Triple Boss", "scene": "res://scenes/level_6.tscn"},
	{"name": "Endless", "scene": "res://scenes/level_endless.tscn"},
]

# Upgrade catalog. Each key maps to max_level, per-level cost list, and
# the per-level effect size (raw — callers convert to gameplay units).
const UPGRADES: Dictionary = {
	"hp": {
		"name": "Max HP",
		"description": "+10 Max HP per level",
		"max_level": 5,
		"costs": [50, 100, 200, 400, 800],
		"per_level": 10.0,
	},
	"fire_rate": {
		"name": "Fire Rate",
		"description": "+10% fire rate per level",
		"max_level": 4,
		"costs": [100, 200, 400, 800],
		"per_level": 0.1,
	},
	"weapon_duration": {
		"name": "Weapon Duration",
		"description": "+2s weapon pickup duration per level",
		"max_level": 4,
		"costs": [80, 160, 320, 640],
		"per_level": 2.0,
	},
}

var current_level: int = 0
var best_kills: Array[int] = []
var banked_kills: int = 0
var upgrade_levels: Dictionary = {
	"hp": 0,
	"fire_rate": 0,
	"weapon_duration": 0,
}

# Per-weapon upgrade tier the player currently owns. Key is the
# GameManager weapon_id int (1..4 for the shipped weapons). Value is
# 0-indexed tier — 0 is the free default.
var weapon_tiers: Dictionary = {}

# Whether each weapon is unlocked. Vanilla weapons (Shotgun / MG / Sniper
# / Rocket) default to true. Weapons listed in GameManager.WEAPON_UNLOCK_
# COSTS default to false and are bought via unlock_weapon.
var unlocked_weapons: Dictionary = {}

# Weapon the player has equipped as the starting / base weapon for every
# run. When a crate pickup expires, GameManager reverts to this instead
# of the pistol. Default is GameManager.WEAPON_DEFAULT (the pistol).
var selected_weapon: int = 0


func _ready() -> void:
	best_kills.clear()
	for _i in LEVELS.size():
		best_kills.append(0)
	for weapon_id in GameManager.WEAPON_TIERS.keys():
		weapon_tiers[weapon_id] = 0
		unlocked_weapons[weapon_id] = not GameManager.WEAPON_UNLOCK_COSTS.has(weapon_id)
	_load_progress()


func level_count() -> int:
	return LEVELS.size()


func current_name() -> String:
	return LEVELS[clamp(current_level, 0, LEVELS.size() - 1)].name


func current_scene_path() -> String:
	return LEVELS[clamp(current_level, 0, LEVELS.size() - 1)].scene


func has_next() -> bool:
	return current_level < LEVELS.size() - 1


func advance() -> void:
	if has_next():
		current_level += 1
		level_changed.emit(current_level)


func start_level(level_index: int) -> void:
	current_level = clamp(level_index, 0, LEVELS.size() - 1)
	level_changed.emit(current_level)
	load_current()


func load_current() -> void:
	get_tree().change_scene_to_file(current_scene_path())


func load_next() -> void:
	if not has_next():
		return
	advance()
	load_current()


func reload_current() -> void:
	get_tree().reload_current_scene()


func go_to_title() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func record_kills(level_index: int, kills: int) -> bool:
	if level_index < 0 or level_index >= LEVELS.size():
		return false
	if kills <= best_kills[level_index]:
		return false
	best_kills[level_index] = kills
	best_kills_updated.emit(level_index, kills)
	_save_progress()
	return true


func best_for(level_index: int) -> int:
	if level_index < 0 or level_index >= best_kills.size():
		return 0
	return best_kills[level_index]


func best_total() -> int:
	var total: int = 0
	for k in best_kills:
		total += k
	return total


# Runs kill into the permanent bank that the store spends.
func add_banked_kills(n: int) -> void:
	if n <= 0:
		return
	banked_kills += n
	banked_kills_changed.emit(banked_kills)
	_save_progress()


func upgrade_level(key: String) -> int:
	return int(upgrade_levels.get(key, 0))


func upgrade_max_level(key: String) -> int:
	var entry: Dictionary = UPGRADES.get(key, {})
	return int(entry.get("max_level", 0))


# -1 means maxed out. Otherwise the cost to buy the next level.
func upgrade_next_cost(key: String) -> int:
	var entry: Dictionary = UPGRADES.get(key, {})
	var level: int = upgrade_level(key)
	var max_level: int = int(entry.get("max_level", 0))
	if level >= max_level:
		return -1
	var costs: Array = entry.get("costs", [])
	if level >= costs.size():
		return -1
	return int(costs[level])


func buy_upgrade(key: String) -> bool:
	var cost: int = upgrade_next_cost(key)
	if cost < 0 or banked_kills < cost:
		return false
	banked_kills -= cost
	upgrade_levels[key] = upgrade_level(key) + 1
	banked_kills_changed.emit(banked_kills)
	upgrade_purchased.emit(key, upgrade_levels[key])
	_save_progress()
	return true


# Effective stats applied by GameManager / soldier at run start.
func effective_max_hp(base_max_hp: int) -> int:
	return base_max_hp + upgrade_level("hp") * 10


func effective_fire_rate_multiplier() -> float:
	return 1.0 + upgrade_level("fire_rate") * 0.1


func effective_weapon_duration(base_duration: float) -> float:
	return base_duration + upgrade_level("weapon_duration") * 2.0


# Arsenal: per-weapon tier helpers -----------------------------------

func get_weapon_tier(weapon_id: int) -> int:
	return int(weapon_tiers.get(weapon_id, 0))


func weapon_max_tier_index(weapon_id: int) -> int:
	var tiers: Array = GameManager.WEAPON_TIERS.get(weapon_id, [])
	return max(tiers.size() - 1, 0)


# -1 if already at max tier.
func weapon_next_upgrade_cost(weapon_id: int) -> int:
	var tiers: Array = GameManager.WEAPON_TIERS.get(weapon_id, [])
	var current: int = get_weapon_tier(weapon_id)
	var next_index: int = current + 1
	if next_index >= tiers.size():
		return -1
	return int(tiers[next_index].get("upgrade_cost", 0))


func upgrade_weapon(weapon_id: int) -> bool:
	var cost: int = weapon_next_upgrade_cost(weapon_id)
	if cost < 0 or banked_kills < cost:
		return false
	banked_kills -= cost
	weapon_tiers[weapon_id] = get_weapon_tier(weapon_id) + 1
	banked_kills_changed.emit(banked_kills)
	weapon_tier_changed.emit(weapon_id, int(weapon_tiers[weapon_id]))
	_save_progress()
	return true


func is_weapon_unlocked(weapon_id: int) -> bool:
	return bool(unlocked_weapons.get(weapon_id, true))


func weapon_unlock_cost(weapon_id: int) -> int:
	return int(GameManager.WEAPON_UNLOCK_COSTS.get(weapon_id, 0))


func unlock_weapon(weapon_id: int) -> bool:
	if is_weapon_unlocked(weapon_id):
		return false
	var cost: int = weapon_unlock_cost(weapon_id)
	if cost <= 0 or banked_kills < cost:
		return false
	banked_kills -= cost
	unlocked_weapons[weapon_id] = true
	banked_kills_changed.emit(banked_kills)
	weapon_unlocked.emit(weapon_id)
	_save_progress()
	return true


func set_selected_weapon(weapon_id: int) -> bool:
	# Pistol (WEAPON_DEFAULT) is always equippable; anything else must
	# be unlocked first so the player can't equip a weapon they don't
	# own yet.
	if weapon_id != GameManager.WEAPON_DEFAULT and not is_weapon_unlocked(weapon_id):
		return false
	if weapon_id == selected_weapon:
		return false
	selected_weapon = weapon_id
	selected_weapon_changed.emit(selected_weapon)
	_save_progress()
	return true


func _load_progress() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PROGRESS_PATH) != OK:
		return
	for i in LEVELS.size():
		best_kills[i] = int(cfg.get_value("progress", "best_kills_%d" % i, 0))
	banked_kills = int(cfg.get_value("progress", "banked_kills", 0))
	for key in UPGRADES.keys():
		upgrade_levels[key] = int(cfg.get_value("upgrades", key, 0))
	for weapon_id in GameManager.WEAPON_TIERS.keys():
		weapon_tiers[weapon_id] = int(cfg.get_value("arsenal", "tier_%d" % int(weapon_id), 0))
		var default_unlocked: bool = not GameManager.WEAPON_UNLOCK_COSTS.has(weapon_id)
		unlocked_weapons[weapon_id] = bool(cfg.get_value("arsenal", "unlocked_%d" % int(weapon_id), default_unlocked))
	selected_weapon = int(cfg.get_value("arsenal", "selected_weapon", GameManager.WEAPON_DEFAULT))


func _save_progress() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	for i in LEVELS.size():
		cfg.set_value("progress", "best_kills_%d" % i, best_kills[i])
	cfg.set_value("progress", "banked_kills", banked_kills)
	for key in UPGRADES.keys():
		cfg.set_value("upgrades", key, upgrade_level(key))
	for weapon_id in weapon_tiers.keys():
		cfg.set_value("arsenal", "tier_%d" % int(weapon_id), int(weapon_tiers[weapon_id]))
	for weapon_id in unlocked_weapons.keys():
		cfg.set_value("arsenal", "unlocked_%d" % int(weapon_id), bool(unlocked_weapons[weapon_id]))
	cfg.set_value("arsenal", "selected_weapon", selected_weapon)
	cfg.save(PROGRESS_PATH)
