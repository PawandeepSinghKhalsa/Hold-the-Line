extends Node

# Autoload singleton. Phase 1+2 state: lane geometry, run state, zombie count.
# Later phases will add kill count, supercharge, gate multipliers, level index.

signal run_ended(won: bool)
signal zombies_remaining_changed(remaining: int)

const FORWARD_SPEED := 2.0
const LANE_X_POSITIONS := [-1.5, 0.0, 1.5]
const LANE_COUNT := 3
const BRIDGE_LENGTH := 100.0

var is_running: bool = false
var zombies_total: int = 0
var zombies_remaining: int = 0


func reset() -> void:
	is_running = true
	zombies_total = 0
	zombies_remaining = 0
	zombies_remaining_changed.emit(zombies_remaining)


func set_level_zombie_count(n: int) -> void:
	zombies_total = n
	zombies_remaining = n
	zombies_remaining_changed.emit(zombies_remaining)


func on_zombie_killed() -> void:
	if not is_running:
		return
	zombies_remaining = max(0, zombies_remaining - 1)
	zombies_remaining_changed.emit(zombies_remaining)
	if zombies_remaining == 0:
		end_run(true)


func end_run(won: bool) -> void:
	if not is_running:
		return
	is_running = false
	run_ended.emit(won)
