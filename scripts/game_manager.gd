extends Node

# Autoload singleton. Phase 3+4 state: lane geometry, run state, zombie
# count, squad size + clone formation math for multiplier gates, and the
# supercharge meter used for tap-to-spawn bonus clones.

signal run_ended(won: bool)
signal zombies_remaining_changed(remaining: int)
signal squad_changed(new_size: int)
signal supercharge_changed(fill_pct: float)

const FORWARD_SPEED := 2.0
const LANE_X_POSITIONS := [-1.5, 0.0, 1.5]
const LANE_COUNT := 3
const BRIDGE_LENGTH := 100.0

# Clone formation: rows of 3, behind the leader, spaced out so bullets
# fire from distinct lanes.
const CLONES_PER_ROW := 3
const CLONE_ROW_SPACING := 1.0
const CLONE_COL_SPACING := 0.8
const CLONE_SCENE_PATH := "res://scenes/clone.tscn"

# Supercharge tuning.
const SUPERCHARGE_MAX := 100.0
const KILL_CHARGE_AMOUNT := 10.0
const SUPERCHARGE_BONUS_MIN := 2
const SUPERCHARGE_BONUS_MAX := 4

var is_running: bool = false
var zombies_total: int = 0
var zombies_remaining: int = 0
var squad_size: int = 1
var supercharge: float = 0.0


func reset() -> void:
	is_running = true
	zombies_total = 0
	zombies_remaining = 0
	squad_size = 1
	supercharge = 0.0
	zombies_remaining_changed.emit(zombies_remaining)
	squad_changed.emit(squad_size)
	supercharge_changed.emit(supercharge)


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


func add_kill_charge(amount: float = KILL_CHARGE_AMOUNT) -> void:
	if not is_running:
		return
	supercharge = min(SUPERCHARGE_MAX, supercharge + amount)
	supercharge_changed.emit(supercharge)


# Spend a full supercharge bar on bonus clones. Returns the number of
# clones spawned, or 0 if the bar wasn't full / no leader could be found.
func try_trigger_supercharge() -> int:
	if not is_running:
		return 0
	if supercharge < SUPERCHARGE_MAX:
		return 0
	var leader: Node3D = get_tree().get_first_node_in_group("soldier") as Node3D
	if leader == null:
		return 0
	var bonus: int = randi_range(SUPERCHARGE_BONUS_MIN, SUPERCHARGE_BONUS_MAX)
	_spawn_bonus_clones(leader, bonus)
	supercharge = 0.0
	supercharge_changed.emit(supercharge)
	return bonus


func _spawn_bonus_clones(leader: Node3D, count: int) -> void:
	if count <= 0:
		return
	var clone_scene: PackedScene = load(CLONE_SCENE_PATH) as PackedScene
	if clone_scene == null:
		return
	var before: int = squad_size
	squad_size += count
	squad_changed.emit(squad_size)
	var tree: SceneTree = leader.get_tree()
	for i in count:
		var clone_node: Node = clone_scene.instantiate()
		var clone: CharacterBody3D = clone_node as CharacterBody3D
		if clone == null:
			continue
		tree.current_scene.add_child(clone)
		var clone_index: int = (before - 1) + i
		var offset: Vector3 = clone_offset_for_index(clone_index)
		clone.set("leader", leader)
		clone.set("follow_offset", offset)
		clone.global_position = leader.global_position + offset


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
