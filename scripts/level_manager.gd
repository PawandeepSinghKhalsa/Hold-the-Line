extends Node

# Autoload singleton. Tracks which level the player is on and where to find
# its scene file. GameManager owns run state; LevelManager owns progression
# and persists best-kill counts per level to user://progress.cfg.

signal level_changed(level_index: int)
signal best_kills_updated(level_index: int, kills: int)

const PROGRESS_PATH := "user://progress.cfg"

const LEVELS: Array = [
	{
		"name": "Level 1",
		"scene": "res://scenes/main.tscn",
	},
	{
		"name": "Level 2",
		"scene": "res://scenes/level_2.tscn",
	},
	{
		"name": "Level 3",
		"scene": "res://scenes/level_3.tscn",
	},
	{
		"name": "Level 4",
		"scene": "res://scenes/level_4.tscn",
	},
	{
		"name": "Level 5 - Twin Bosses",
		"scene": "res://scenes/level_5.tscn",
	},
	{
		"name": "Level 6 - Triple Boss",
		"scene": "res://scenes/level_6.tscn",
	},
]

var current_level: int = 0
var best_kills: Array[int] = []


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
	var path: String = current_scene_path()
	get_tree().change_scene_to_file(path)


func load_next() -> void:
	if not has_next():
		return
	advance()
	load_current()


func reload_current() -> void:
	get_tree().reload_current_scene()


func go_to_title() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")


# Returns true if the given kill count beats the stored best for that
# level. Caller (usually the HUD on run end) uses the result to show a
# "NEW RECORD" badge.
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


func _load_progress() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(PROGRESS_PATH)
	if err != OK:
		return
	for i in LEVELS.size():
		best_kills[i] = int(cfg.get_value("progress", "best_kills_%d" % i, 0))


func _save_progress() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	for i in LEVELS.size():
		cfg.set_value("progress", "best_kills_%d" % i, best_kills[i])
	cfg.save(PROGRESS_PATH)
