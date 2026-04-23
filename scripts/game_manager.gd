extends Node

# Autoload singleton. Tracks squad, weapon tier, and tuning constants.
# Referenced from any script as `GameManager.<name>`.

signal squad_size_changed(new_size: int)
signal weapon_tier_changed(new_tier: int)
signal game_over(distance_traveled: float)

const FORWARD_SPEED := 5.0
const STRAFE_SPEED := 7.0
const BRIDGE_HALF_WIDTH := 2.0

const WEAPON_TIERS := [
	{"damage": 1, "fire_rate": 1.0, "bullet_speed": 20.0},
	{"damage": 1, "fire_rate": 2.0, "bullet_speed": 22.0},
	{"damage": 2, "fire_rate": 2.0, "bullet_speed": 24.0},
	{"damage": 2, "fire_rate": 3.0, "bullet_speed": 26.0},
	{"damage": 3, "fire_rate": 3.0, "bullet_speed": 28.0},
	{"damage": 3, "fire_rate": 4.0, "bullet_speed": 30.0},
]

var squad_size: int = 1
var weapon_tier: int = 0
var distance_traveled: float = 0.0
var is_running: bool = false


func reset() -> void:
	squad_size = 1
	weapon_tier = 0
	distance_traveled = 0.0
	is_running = true
	squad_size_changed.emit(squad_size)
	weapon_tier_changed.emit(weapon_tier)


func weapon_damage() -> int:
	return WEAPON_TIERS[weapon_tier].damage


func weapon_fire_rate() -> float:
	return WEAPON_TIERS[weapon_tier].fire_rate


func weapon_bullet_speed() -> float:
	return WEAPON_TIERS[weapon_tier].bullet_speed


func upgrade_weapon(steps: int = 1) -> void:
	weapon_tier = min(WEAPON_TIERS.size() - 1, weapon_tier + steps)
	weapon_tier_changed.emit(weapon_tier)


func apply_multiplier(multiplier: int) -> int:
	var before := squad_size
	squad_size = max(1, squad_size * multiplier)
	squad_size_changed.emit(squad_size)
	return squad_size - before


func add_clones(amount: int) -> void:
	squad_size += amount
	squad_size_changed.emit(squad_size)


func remove_clone() -> void:
	squad_size = max(0, squad_size - 1)
	squad_size_changed.emit(squad_size)
	if squad_size <= 0 and is_running:
		is_running = false
		game_over.emit(distance_traveled)


func end_run() -> void:
	if not is_running:
		return
	is_running = false
	game_over.emit(distance_traveled)


func kill_leader() -> void:
	squad_size = 0
	squad_size_changed.emit(squad_size)
	end_run()
