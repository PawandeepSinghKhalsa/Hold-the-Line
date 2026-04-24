extends Control

# Title screen. Three primary buttons: Play (starts Level 1), Level
# Select (opens the level-select screen), Store (permanent upgrades).
# Shows the total best kills across all levels as a player stat.

@onready var best_label: Label = $Margin/VBox/BestLabel
@onready var play_button: Button = $Margin/VBox/PlayButton
@onready var level_select_button: Button = $Margin/VBox/LevelSelectButton
@onready var store_button: Button = $Margin/VBox/StoreButton
@onready var arsenal_button: Button = $Margin/VBox/ArsenalButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	level_select_button.pressed.connect(_on_level_select_pressed)
	store_button.pressed.connect(_on_store_pressed)
	arsenal_button.pressed.connect(_on_arsenal_pressed)
	best_label.text = "Best Run Total: %d kills   |   Banked: %d" % [
		LevelManager.best_total(),
		LevelManager.banked_kills,
	]


func _on_play_pressed() -> void:
	LevelManager.start_level(0)


func _on_level_select_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")


func _on_store_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/store.tscn")


func _on_arsenal_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/arsenal.tscn")
