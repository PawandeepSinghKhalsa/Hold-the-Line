extends CanvasLayer

# Minimal HUD: squad count, weapon tier, distance, game-over message.

@onready var squad_label: Label = $Margin/VBox/SquadLabel
@onready var weapon_label: Label = $Margin/VBox/WeaponLabel
@onready var distance_label: Label = $Margin/VBox/DistanceLabel
@onready var game_over_label: Label = $Margin/VBox/GameOverLabel
@onready var hint_label: Label = $Margin/VBox/HintLabel


func _ready() -> void:
	GameManager.squad_size_changed.connect(_on_squad_changed)
	GameManager.weapon_tier_changed.connect(_on_weapon_changed)
	GameManager.game_over.connect(_on_game_over)
	game_over_label.visible = false
	_on_squad_changed(GameManager.squad_size)
	_on_weapon_changed(GameManager.weapon_tier)


func _process(_delta: float) -> void:
	if GameManager.is_running:
		distance_label.text = "Distance: %.1f m" % GameManager.distance_traveled


func _on_squad_changed(new_size: int) -> void:
	squad_label.text = "Squad: %d" % new_size


func _on_weapon_changed(new_tier: int) -> void:
	weapon_label.text = "Weapon: Tier %d" % (new_tier + 1)


func _on_game_over(distance: float) -> void:
	game_over_label.visible = true
	if GameManager.squad_size <= 0:
		game_over_label.text = "You fell. Distance: %.1f m" % distance
	else:
		game_over_label.text = "You held the line! Distance: %.1f m" % distance
	hint_label.text = "Refresh to play again"
