extends Node

# Autoload singleton. Tracks which level the player is on and where to find
# its scene file. GameManager owns run state; LevelManager owns progression.

signal level_changed(level_index: int)

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
]

var current_level: int = 0


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
