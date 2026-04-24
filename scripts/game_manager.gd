extends Node

# Autoload singleton. Phase 3 state: lane geometry, run state, zombie count,
# squad size + clone formation math for multiplier gates.

signal run_ended(won: bool)
signal zombies_remaining_changed(remaining: int)
signal squad_changed(new_size: int)

const FORWARD_SPEED := 2.0
const LANE_X_POSITIONS := [-1.5, 0.0, 1.5]
const LANE_COUNT := 3
const BRIDGE_LENGTH := 100.0

# Clone formation: rows of 3, behind the leader, spaced out so bullets
# fire from distinct lanes.
const CLONES_PER_ROW := 3
const CLONE_ROW_SPACING := 1.0
const CLONE_COL_SPACING := 0.8

var is_running: bool = false
var zombies_total: int = 0
var zombies_remaining: int = 0
var squad_size: int = 1


func reset() -> void:
	is_running = true
	zombies_total = 0
	zombies_remaining = 0
	squad_size = 1
	zombies_remaining_changed.emit(zombies_remaining)
	squad_changed.emit(squad_size)


func set_level_zombie_count(n: int) -> void:
	zombies_total = n
	zombies_remaining = n
	zombies_remaining_changed.emit(zombies_remaining)


func add_zombies(n: int) -> void:
	zombies_total += n
	zombies_remaining += n
	zombies_remaining_changed.emit(zombies_remaining)


func on_zombie_killed() -> void:
	if not is_running:
		return
	zombies_remaining = max(0, zombies_remaining - 1)
	zombies_remaining_changed.emit(zombies_remaining)
	if zombies_remaining == 0:
		end_run(true)


func apply_multiplier(multiplier: int) -> int:
	var before: int = squad_size
	squad_size = max(1, squad_size * multiplier)
	squad_changed.emit(squad_size)
	return squad_size - before


func on_clone_spawned() -> void:
	pass  # Placeholder for future tracking.


func end_run(won: bool) -> void:
	if not is_running:
		return
	is_running = false
	run_ended.emit(won)


# Compute the local offset (relative to the leader) of the Nth clone in
# the squad. Clones are arranged in rows of CLONES_PER_ROW behind the
# leader, centred horizontally, each row further back along +Z.
func clone_offset_for_index(clone_index: int) -> Vector3:
	var row: int = clone_index / CLONES_PER_ROW
	var col: int = clone_index % CLONES_PER_ROW
	var x: float = (col - (CLONES_PER_ROW - 1) / 2.0) * CLONE_COL_SPACING
	var z: float = (row + 1) * CLONE_ROW_SPACING
	return Vector3(x, 0.0, z)
