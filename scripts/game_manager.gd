extends Node

# Autoload singleton. Phase 1: only forward movement and lane geometry.
# Later phases will add kill count, supercharge, zombie count, level index.

signal game_over

const FORWARD_SPEED := 2.0
const LANE_X_POSITIONS := [-1.5, 0.0, 1.5]
const LANE_COUNT := 3
const BRIDGE_LENGTH := 100.0

var is_running: bool = false


func reset() -> void:
	is_running = true


func end_run() -> void:
	if not is_running:
		return
	is_running = false
	game_over.emit()
