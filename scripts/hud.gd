extends CanvasLayer

# Phase 1-4 HUD: lane, squad, zombies remaining, distance, supercharge
# bar + trigger button, win/lose banner.

@onready var lane_label: Label = $Margin/VBox/LaneLabel
@onready var squad_label: Label = $Margin/VBox/SquadLabel
@onready var zombies_label: Label = $Margin/VBox/ZombiesLabel
@onready var distance_label: Label = $Margin/VBox/DistanceLabel
@onready var supercharge_bar: ProgressBar = $Margin/VBox/SuperchargeBar
@onready var hint_label: Label = $Margin/VBox/HintLabel
@onready var banner: Label = $Margin/VBox/Banner
@onready var supercharge_button: Button = $SuperchargeButton


func _ready() -> void:
	GameManager.run_ended.connect(_on_run_ended)
	GameManager.zombies_remaining_changed.connect(_on_zombies_changed)
	GameManager.squad_changed.connect(_on_squad_changed)
	GameManager.supercharge_changed.connect(_on_supercharge_changed)
	supercharge_button.pressed.connect(_on_supercharge_button_pressed)
	banner.visible = false
	_on_zombies_changed(GameManager.zombies_remaining)
	_on_squad_changed(GameManager.squad_size)
	_on_supercharge_changed(GameManager.supercharge)
	var soldier_node: Node = get_tree().get_first_node_in_group("soldier")
	if soldier_node != null and soldier_node.has_signal("lane_changed"):
		soldier_node.lane_changed.connect(_on_lane_changed)
		_on_lane_changed(soldier_node.lane_index)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("supercharge"):
		GameManager.try_trigger_supercharge()


func _process(_delta: float) -> void:
	var soldier: Node3D = get_tree().get_first_node_in_group("soldier") as Node3D
	if soldier == null:
		return
	var distance: float = max(0.0, -soldier.global_position.z)
	distance_label.text = "Distance: %.1f m" % distance


func _on_lane_changed(new_lane: int) -> void:
	lane_label.text = "Lane: %d" % (new_lane + 1)


func _on_squad_changed(new_size: int) -> void:
	squad_label.text = "Squad: %d" % new_size


func _on_zombies_changed(remaining: int) -> void:
	zombies_label.text = "Zombies: %d" % remaining


func _on_supercharge_changed(fill: float) -> void:
	supercharge_bar.value = fill
	var is_full: bool = fill >= GameManager.SUPERCHARGE_MAX
	supercharge_button.disabled = not is_full
	if is_full:
		supercharge_button.modulate = Color(1.0, 0.95, 0.4, 1.0)
	else:
		supercharge_button.modulate = Color(0.55, 0.55, 0.55, 0.6)


func _on_supercharge_button_pressed() -> void:
	GameManager.try_trigger_supercharge()


func _on_run_ended(won: bool) -> void:
	banner.visible = true
	supercharge_button.disabled = true
	supercharge_button.modulate = Color(0.4, 0.4, 0.4, 0.4)
	if won:
		banner.text = "VICTORY — Horde cleared"
		banner.modulate = Color(0.4, 1, 0.5, 1)
	else:
		banner.text = "GAME OVER — Zombie reached you"
		banner.modulate = Color(1, 0.4, 0.4, 1)
	hint_label.text = "Refresh to play again"
