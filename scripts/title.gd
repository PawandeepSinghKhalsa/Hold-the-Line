extends Control

# Title screen. Two primary buttons: Play (starts Level 1) and
# Level Select (opens the level-select screen). Shows the total
# best kills across all levels as a persistent player stat.

@onready var best_label: Label = $Margin/VBox/BestLabel
@onready var play_button: Button = $Margin/VBox/PlayButton
@onready var level_select_button: Button = $Margin/VBox/LevelSelectButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	level_select_button.pressed.connect(_on_level_select_pressed)
	best_label.text = "Best Run Total: %d kills" % LevelManager.best_total()


func _on_play_pressed() -> void:
	LevelManager.start_level(0)


func _on_level_select_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/level_select.tscn")
