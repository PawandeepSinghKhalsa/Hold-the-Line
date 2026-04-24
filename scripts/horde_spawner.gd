extends Node3D

# Spawns a rectangular block of zombies across the three lanes. Back rows
# (controlled by `tough_rows_from_back`) get max_hp=2 so they take two
# bullets to drop, creating a natural difficulty ramp deeper into the
# horde without bloating the total zombie count.

@export var zombie_scene: PackedScene
@export var zombies_per_lane: int = 34
@export var row_spacing: float = 1.2
@export var horde_front_z: float = -95.0
@export var tough_rows_from_back: int = 0
@export var tough_hp: int = 2


func _ready() -> void:
	call_deferred("_spawn_horde")


func _spawn_horde() -> void:
	if zombie_scene == null:
		return
	var total: int = zombies_per_lane * GameManager.LANE_COUNT
	GameManager.add_zombies(total)

	var tough_threshold: int = zombies_per_lane - tough_rows_from_back

	for lane_idx in GameManager.LANE_COUNT:
		for row in zombies_per_lane:
			var zombie_node: Node = zombie_scene.instantiate()
			var zombie: Node3D = zombie_node as Node3D
			if zombie == null:
				continue
			# Must set max_hp before add_child so zombie._ready() sees the
			# right value and picks the tough material.
			if row >= tough_threshold and tough_rows_from_back > 0:
				zombie.set("max_hp", tough_hp)
			zombie.set("lane_index", lane_idx)
			get_tree().current_scene.add_child(zombie)
			var x_jitter: float = randf_range(-0.4, 0.4)
			var z_jitter: float = randf_range(-0.3, 0.3)
			zombie.global_position = Vector3(
				GameManager.LANE_X_POSITIONS[lane_idx] + x_jitter,
				0.1,
				horde_front_z - row * row_spacing + z_jitter
			)
