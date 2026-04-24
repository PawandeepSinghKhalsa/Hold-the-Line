extends CanvasLayer

# Phase 1-5 HUD: level, lane, squad, zombies remaining, distance,
# supercharge bar + trigger button, win/lose banner, and a post-run
# button that routes Next Level (on victory) or Retry (on defeat).

@onready var level_label: Label = $Margin/VBox/LevelLabel
@onready var leader_hp_label: Label = $Margin/VBox/LeaderHpLabel
@onready var leader_hp_bar: ProgressBar = $Margin/VBox/LeaderHpBar
@onready var lane_label: Label = $Margin/VBox/LaneLabel
@onready var squad_label: Label = $Margin/VBox/SquadLabel
@onready var zombies_label: Label = $Margin/VBox/ZombiesLabel
@onready var distance_label: Label = $Margin/VBox/DistanceLabel
@onready var weapon_label: Label = $Margin/VBox/WeaponLabel
@onready var supercharge_bar: ProgressBar = $Margin/VBox/SuperchargeBar
@onready var hint_label: Label = $Margin/VBox/HintLabel
@onready var banner: Label = $Margin/VBox/Banner
@onready var supercharge_button: Button = $SuperchargeButton
@onready var post_run_button: Button = $PostRunButton
@onready var main_menu_button: Button = $MainMenuButton
@onready var pause_button: Button = $PauseButton
@onready var pause_overlay: Control = $PauseOverlay
@onready var resume_button: Button = $PauseOverlay/Panel/ResumeButton
@onready var pause_main_menu_button: Button = $PauseOverlay/Panel/PauseMainMenuButton
@onready var damage_flash: ColorRect = $DamageFlash

var _last_run_won: bool = false
var _last_hp: int = -1


func _ready() -> void:
	GameManager.run_ended.connect(_on_run_ended)
	GameManager.zombies_remaining_changed.connect(_on_zombies_changed)
	GameManager.squad_changed.connect(_on_squad_changed)
	GameManager.supercharge_changed.connect(_on_supercharge_changed)
	GameManager.supercharge_uses_changed.connect(_on_supercharge_uses_changed)
	GameManager.supercharge_boost_changed.connect(_on_supercharge_boost_changed)
	GameManager.weapon_changed.connect(_on_weapon_changed)
	supercharge_button.pressed.connect(_on_supercharge_button_pressed)
	post_run_button.pressed.connect(_on_post_run_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	pause_button.pressed.connect(_on_pause_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	pause_main_menu_button.pressed.connect(_on_main_menu_pressed)
	banner.visible = false
	post_run_button.visible = false
	main_menu_button.visible = false
	pause_overlay.visible = false
	get_tree().paused = false
	_on_zombies_changed(GameManager.zombies_remaining)
	_on_squad_changed(GameManager.squad_size)
	_on_supercharge_changed(GameManager.supercharge)
	_on_supercharge_uses_changed(GameManager.supercharge_uses_remaining)
	_on_supercharge_boost_changed(GameManager.is_boost_active(), 0.0)
	_on_weapon_changed(GameManager.active_weapon, GameManager.weapon_time_left())
	level_label.text = LevelManager.current_name()
	if GameManager.is_endless:
		level_label.text = "Endless — Wave %d" % GameManager.wave_number
		GameManager.wave_advanced.connect(_on_wave_advanced)
	var soldier_node: Node = get_tree().get_first_node_in_group("soldier")
	if soldier_node != null:
		if soldier_node.has_signal("lane_changed"):
			soldier_node.lane_changed.connect(_on_lane_changed)
			_on_lane_changed(soldier_node.lane_index)
		if soldier_node.has_signal("hp_changed"):
			soldier_node.hp_changed.connect(_on_leader_hp_changed)
			_on_leader_hp_changed(soldier_node.hp, soldier_node.max_hp)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("supercharge"):
		GameManager.try_trigger_supercharge()
	elif event.is_action_pressed("pause"):
		_toggle_pause()


func _toggle_pause() -> void:
	if not GameManager.is_running:
		return
	var now_paused: bool = not get_tree().paused
	get_tree().paused = now_paused
	pause_overlay.visible = now_paused
	pause_button.visible = not now_paused


func _on_pause_pressed() -> void:
	_toggle_pause()


func _on_resume_pressed() -> void:
	_toggle_pause()


func _process(_delta: float) -> void:
	var soldier: Node3D = get_tree().get_first_node_in_group("soldier") as Node3D
	if soldier != null:
		var distance: float = max(0.0, -soldier.global_position.z)
		distance_label.text = "Distance: %.1f m" % distance
	if GameManager.is_boost_active():
		_refresh_button_label()


func _on_lane_changed(new_lane: int) -> void:
	lane_label.text = "Lane: %d" % (new_lane + 1)


func _on_leader_hp_changed(current: int, maximum: int) -> void:
	leader_hp_bar.max_value = maximum
	leader_hp_bar.value = current
	leader_hp_label.text = "Leader HP: %d / %d" % [current, maximum]
	var fraction: float = float(current) / float(max(maximum, 1))
	if fraction > 0.6:
		leader_hp_bar.modulate = Color(0.3, 1, 0.4, 1)
	elif fraction > 0.3:
		leader_hp_bar.modulate = Color(1, 0.9, 0.35, 1)
	else:
		leader_hp_bar.modulate = Color(1, 0.35, 0.35, 1)
	# Flash red when HP drops (not on initial set or refill).
	if _last_hp != -1 and current < _last_hp:
		_pulse_damage_flash()
	_last_hp = current


func _pulse_damage_flash() -> void:
	damage_flash.color = Color(1, 0.1, 0.1, 0.35)
	var tween: Tween = create_tween()
	tween.tween_property(damage_flash, "color:a", 0.0, 0.25)


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


func _on_weapon_changed(weapon_id: int, time_left: float) -> void:
	var weapon_name: String = GameManager.WEAPON_NAMES.get(weapon_id, "Pistol")
	if time_left > 0.0:
		# Crate override — show live countdown in yellow.
		weapon_label.text = "Weapon: %s (%.1fs)" % [weapon_name, time_left]
		weapon_label.modulate = Color(1, 0.95, 0.4, 1)
	else:
		# Equipped weapon — show name without timer.
		weapon_label.text = "Weapon: %s" % weapon_name
		weapon_label.modulate = Color(1, 1, 1, 1)


func _on_run_ended(won: bool) -> void:
	_last_run_won = won
	banner.visible = true
	supercharge_button.disabled = true
	supercharge_button.modulate = Color(0.4, 0.4, 0.4, 0.4)
	var kills: int = GameManager.kills_this_run
	var new_record: bool = LevelManager.record_kills(LevelManager.current_level, kills)
	var record_suffix: String = "  ★ NEW RECORD" if new_record else ""
	# Every run banks its kills toward the Store — win or lose.
	LevelManager.add_banked_kills(kills)
	var banked_suffix: String = "  (+%d banked)" % kills if kills > 0 else ""
	if won:
		banner.text = "VICTORY — %d kills%s%s" % [kills, record_suffix, banked_suffix]
		banner.modulate = Color(0.4, 1, 0.5, 1)
		Effects.spawn_victory_celebration()
		if LevelManager.has_next():
			post_run_button.text = "NEXT LEVEL"
		else:
			post_run_button.text = "YOU BEAT THE GAME — play again"
	else:
		banner.text = "GAME OVER — %d kills%s%s" % [kills, record_suffix, banked_suffix]
		banner.modulate = Color(1, 0.4, 0.4, 1)
		post_run_button.text = "RETRY"
	hint_label.text = ""
	post_run_button.visible = true
	main_menu_button.visible = true
	pause_button.visible = false
	pause_overlay.visible = false


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	LevelManager.go_to_title()


func _on_wave_advanced(wave: int) -> void:
	level_label.text = "Endless — Wave %d" % wave


func _on_post_run_pressed() -> void:
	if not _last_run_won:
		LevelManager.reload_current()
		return
	if LevelManager.has_next():
		LevelManager.load_next()
	else:
		LevelManager.current_level = 0
		LevelManager.load_current()
