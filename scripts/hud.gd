extends CanvasLayer

# Phase 1-5 HUD: level, lane, squad, zombies remaining, distance,
# supercharge bar + trigger button, win/lose banner, and a post-run
# button that routes Next Level (on victory) or Retry (on defeat).

@onready var level_label: Label = $Margin/VBox/LevelLabel
@onready var lane_label: Label = $Margin/VBox/LaneLabel
@onready var squad_label: Label = $Margin/VBox/SquadLabel
@onready var zombies_label: Label = $Margin/VBox/ZombiesLabel
@onready var distance_label: Label = $Margin/VBox/DistanceLabel
@onready var supercharge_bar: ProgressBar = $Margin/VBox/SuperchargeBar
@onready var hint_label: Label = $Margin/VBox/HintLabel
@onready var banner: Label = $Margin/VBox/Banner
@onready var supercharge_button: Button = $SuperchargeButton
@onready var post_run_button: Button = $PostRunButton

var _last_run_won: bool = false


func _ready() -> void:
	GameManager.run_ended.connect(_on_run_ended)
	GameManager.zombies_remaining_changed.connect(_on_zombies_changed)
	GameManager.squad_changed.connect(_on_squad_changed)
	GameManager.supercharge_changed.connect(_on_supercharge_changed)
	GameManager.supercharge_uses_changed.connect(_on_supercharge_uses_changed)
	GameManager.supercharge_boost_changed.connect(_on_supercharge_boost_changed)
	supercharge_button.pressed.connect(_on_supercharge_button_pressed)
	post_run_button.pressed.connect(_on_post_run_pressed)
	banner.visible = false
	post_run_button.visible = false
	_on_zombies_changed(GameManager.zombies_remaining)
	_on_squad_changed(GameManager.squad_size)
	_on_supercharge_changed(GameManager.supercharge)
	_on_supercharge_uses_changed(GameManager.supercharge_uses_remaining)
	_on_supercharge_boost_changed(GameManager.is_boost_active(), 0.0)
	level_label.text = LevelManager.current_name()
	var soldier_node: Node = get_tree().get_first_node_in_group("soldier")
	if soldier_node != null and soldier_node.has_signal("lane_changed"):
		soldier_node.lane_changed.connect(_on_lane_changed)
		_on_lane_changed(soldier_node.lane_index)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("supercharge"):
		GameManager.try_trigger_supercharge()


func _process(_delta: float) -> void:
	var soldier: Node3D = get_tree().get_first_node_in_group("soldier") as Node3D
	if soldier != null:
		var distance: float = max(0.0, -soldier.global_position.z)
		distance_label.text = "Distance: %.1f m" % distance
	if GameManager.is_boost_active():
		_refresh_button_label()


func _on_lane_changed(new_lane: int) -> void:
	lane_label.text = "Lane: %d" % (new_lane + 1)


func _on_squad_changed(new_size: int) -> void:
	squad_label.text = "Squad: %d" % new_size


func _on_zombies_changed(remaining: int) -> void:
	zombies_label.text = "Zombies: %d" % remaining


func _on_supercharge_changed(fill: float) -> void:
	supercharge_bar.value = fill
	_refresh_button_state()


func _on_supercharge_uses_changed(_uses_left: int) -> void:
	_refresh_button_state()


func _on_supercharge_boost_changed(_is_active: bool, _time_left: float) -> void:
	_refresh_button_state()


func _refresh_button_state() -> void:
	var uses: int = GameManager.supercharge_uses_remaining
	var full: bool = GameManager.supercharge >= GameManager.SUPERCHARGE_MAX
	var boost_active: bool = GameManager.is_boost_active()
	var can_fire: bool = full and uses > 0 and not boost_active

	supercharge_button.disabled = not can_fire
	if boost_active:
		supercharge_button.modulate = Color(0.4, 1.0, 0.6, 1.0)
	elif can_fire:
		supercharge_button.modulate = Color(1.0, 0.95, 0.4, 1.0)
	else:
		supercharge_button.modulate = Color(0.55, 0.55, 0.55, 0.6)
	_refresh_button_label()


func _refresh_button_label() -> void:
	var uses: int = GameManager.supercharge_uses_remaining
	if GameManager.is_boost_active():
		supercharge_button.text = "BOOST! %.1fs" % GameManager._boost_time_left
	elif uses <= 0:
		supercharge_button.text = "SUPERCHARGE (spent)"
	else:
		supercharge_button.text = "SUPERCHARGE (%d left)" % uses


func _on_supercharge_button_pressed() -> void:
	GameManager.try_trigger_supercharge()


func _on_run_ended(won: bool) -> void:
	_last_run_won = won
	banner.visible = true
	supercharge_button.disabled = true
	supercharge_button.modulate = Color(0.4, 0.4, 0.4, 0.4)
	var kills: int = GameManager.kills_this_run
	if won:
		banner.text = "VICTORY — %d kills" % kills
		banner.modulate = Color(0.4, 1, 0.5, 1)
		if LevelManager.has_next():
			post_run_button.text = "NEXT LEVEL"
		else:
			post_run_button.text = "YOU BEAT THE GAME — play again"
	else:
		banner.text = "GAME OVER — %d kills before you fell" % kills
		banner.modulate = Color(1, 0.4, 0.4, 1)
		post_run_button.text = "RETRY"
	hint_label.text = ""
	post_run_button.visible = true


func _on_post_run_pressed() -> void:
	if not _last_run_won:
		LevelManager.reload_current()
		return
	if LevelManager.has_next():
		LevelManager.load_next()
	else:
		LevelManager.current_level = 0
		LevelManager.load_current()
