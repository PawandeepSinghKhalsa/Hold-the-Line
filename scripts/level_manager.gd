extends Node

# Autoload singleton. Tracks which level the player is on and where to find
# its scene file. Also owns the player's persistent progression — best kill
# counts per level, banked kills, and purchased upgrade levels — all stored
# in user://progress.cfg via ConfigFile.

signal level_changed(level_index: int)
signal best_kills_updated(level_index: int, kills: int)
signal banked_kills_changed(kills: int)
signal upgrade_purchased(upgrade_key: String, new_level: int)

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


func _ready() -> void:
	best_kills.clear()
	for _i in LEVELS.size():
		best_kills.append(0)
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


func _load_progress() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PROGRESS_PATH) != OK:
		return
	for i in LEVELS.size():
		best_kills[i] = int(cfg.get_value("progress", "best_kills_%d" % i, 0))
	banked_kills = int(cfg.get_value("progress", "banked_kills", 0))
	for key in UPGRADES.keys():
		upgrade_levels[key] = int(cfg.get_value("upgrades", key, 0))


func _save_progress() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	for i in LEVELS.size():
		cfg.set_value("progress", "best_kills_%d" % i, best_kills[i])
	cfg.set_value("progress", "banked_kills", banked_kills)
	for key in UPGRADES.keys():
		cfg.set_value("upgrades", key, upgrade_level(key))
	cfg.save(PROGRESS_PATH)
