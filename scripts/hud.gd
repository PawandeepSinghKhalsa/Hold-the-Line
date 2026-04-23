extends CanvasLayer

# Minimal HUD: squad count, supercharge fill, game-over message.

@onready var squad_label: Label = $Margin/VBox/SquadLabel
@onready var supercharge_bar: ProgressBar = $Margin/VBox/SuperchargeBar
@onready var game_over_label: Label = $Margin/VBox/GameOverLabel


func _ready() -> void:
	GameManager.squad_size_changed.connect(_on_squad_changed)
	GameManager.supercharge_changed.connect(_on_supercharge_changed)
	GameManager.game_over.connect(_on_game_over)
	game_over_label.visible = false
	_on_squad_changed(GameManager.squad_size)
	_on_supercharge_changed(GameManager.supercharge)


func _on_squad_changed(new_size: int) -> void:
	squad_label.text = "Squad: %d" % new_size


func _on_supercharge_changed(fill_pct: float) -> void:
	supercharge_bar.value = fill_pct


func _on_game_over(distance: float) -> void:
	game_over_label.visible = true
	game_over_label.text = "You fell. Distance held: %.1f m" % distance
