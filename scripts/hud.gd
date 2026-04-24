extends CanvasLayer

# Phase 1 HUD: shows current lane (0/1/2), distance travelled, and a hint.
# Game-over banner is wired up now but won't trigger until Phase 2+ adds a
# loss condition.

@onready var lane_label: Label = $Margin/VBox/LaneLabel
@onready var distance_label: Label = $Margin/VBox/DistanceLabel
@onready var hint_label: Label = $Margin/VBox/HintLabel
@onready var game_over_label: Label = $Margin/VBox/GameOverLabel


func _ready() -> void:
	GameManager.game_over.connect(_on_game_over)
	game_over_label.visible = false
	var soldier := get_tree().get_first_node_in_group("soldier")
	if soldier != null and soldier.has_signal("lane_changed"):
		soldier.lane_changed.connect(_on_lane_changed)
		_on_lane_changed(soldier.lane_index)


func _process(_delta: float) -> void:
	var soldier := get_tree().get_first_node_in_group("soldier")
	if soldier == null:
		return
	var distance: float = max(0.0, -soldier.global_position.z)
	distance_label.text = "Distance: %.1f m" % distance


func _on_lane_changed(new_lane: int) -> void:
	lane_label.text = "Lane: %d" % (new_lane + 1)


func _on_game_over() -> void:
	game_over_label.visible = true
