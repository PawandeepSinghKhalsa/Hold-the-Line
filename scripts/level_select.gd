extends Control

# Level select screen. One button per level, labelled with that level's
# best-kill record from LevelManager. Back button returns to title.

@onready var back_button: Button = $Margin/VBox/BackButton
@onready var levels_container: VBoxContainer = $Margin/VBox/Levels


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	_build_level_buttons()


func _build_level_buttons() -> void:
	for child in levels_container.get_children():
		child.queue_free()
	for i in LevelManager.level_count():
		var level_info: Dictionary = LevelManager.LEVELS[i]
		var best: int = LevelManager.best_for(i)
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(340, 80)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.add_theme_font_size_override("font_size", 24)
		var record_text: String = "—" if best <= 0 else "%d kills" % best
		button.text = "%s   |   Best: %s" % [level_info.name, record_text]
		button.pressed.connect(_on_level_pressed.bind(i))
		levels_container.add_child(button)


func _on_level_pressed(index: int) -> void:
	LevelManager.start_level(index)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")
