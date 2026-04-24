extends CanvasLayer

# Phase 1+2 HUD: lane, zombies remaining, distance, win/lose banner.

@onready var lane_label: Label = $Margin/VBox/LaneLabel
@onready var zombies_label: Label = $Margin/VBox/ZombiesLabel
@onready var distance_label: Label = $Margin/VBox/DistanceLabel
@onready var hint_label: Label = $Margin/VBox/HintLabel
@onready var banner: Label = $Margin/VBox/Banner


func _ready() -> void:
	GameManager.run_ended.connect(_on_run_ended)
	GameManager.zombies_remaining_changed.connect(_on_zombies_changed)
	banner.visible = false
	_on_zombies_changed(GameManager.zombies_remaining)
	var soldier_node: Node = get_tree().get_first_node_in_group("soldier")
	if soldier_node != null and soldier_node.has_signal("lane_changed"):
		soldier_node.lane_changed.connect(_on_lane_changed)
		_on_lane_changed(soldier_node.lane_index)


func _process(_delta: float) -> void:
	var soldier: Node3D = get_tree().get_first_node_in_group("soldier") as Node3D
	if soldier == null:
		return
	var distance: float = max(0.0, -soldier.global_position.z)
	distance_label.text = "Distance: %.1f m" % distance


func _on_lane_changed(new_lane: int) -> void:
	lane_label.text = "Lane: %d" % (new_lane + 1)


func _on_zombies_changed(remaining: int) -> void:
	zombies_label.text = "Zombies: %d" % remaining


func _on_run_ended(won: bool) -> void:
	banner.visible = true
	if won:
		banner.text = "VICTORY — Horde cleared"
		banner.modulate = Color(0.4, 1, 0.5, 1)
	else:
		banner.text = "GAME OVER — Zombie reached you"
		banner.modulate = Color(1, 0.4, 0.4, 1)
	hint_label.text = "Refresh to play again"
