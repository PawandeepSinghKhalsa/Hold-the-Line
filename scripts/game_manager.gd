extends Node

# Autoload singleton. Tracks squad size, supercharge, and tuning constants.
# Referenced from any script as `GameManager.<name>`.

signal squad_size_changed(new_size: int)
signal supercharge_changed(fill_pct: float)
signal game_over(distance_traveled: float)

const FORCE_PER_ZOMBIE := 1.0
const RESISTANCE_PER_CLONE := 3.0
const PUSH_SPEED_SCALE := 0.5
const BRIDGE_HALF_WIDTH := 2.0
const BRIDGE_LENGTH := 30.0

const SUPERCHARGE_FILL_RATE := 10.0
const SUPERCHARGE_MAX := 100.0
const SUPERCHARGE_BONUS_MIN := 2
const SUPERCHARGE_BONUS_MAX := 4

var squad_size: int = 1
var supercharge: float = 0.0
var distance_traveled: float = 0.0
var is_running: bool = false


func reset() -> void:
	squad_size = 1
	supercharge = 0.0
	distance_traveled = 0.0
	is_running = true
	squad_size_changed.emit(squad_size)
	supercharge_changed.emit(supercharge)


func _process(delta: float) -> void:
	if not is_running:
		return
	if supercharge < SUPERCHARGE_MAX:
		supercharge = min(SUPERCHARGE_MAX, supercharge + SUPERCHARGE_FILL_RATE * delta)
		supercharge_changed.emit(supercharge)


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


func try_trigger_supercharge() -> int:
	if supercharge < SUPERCHARGE_MAX:
		return 0
	supercharge = 0.0
	supercharge_changed.emit(supercharge)
	var bonus := randi_range(SUPERCHARGE_BONUS_MIN, SUPERCHARGE_BONUS_MAX)
	add_clones(bonus)
	return bonus


func compute_net_push(zombie_count: int) -> float:
	var push := zombie_count * FORCE_PER_ZOMBIE
	var resist := squad_size * RESISTANCE_PER_CLONE
	return push - resist
