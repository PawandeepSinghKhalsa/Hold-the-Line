extends Node3D

# Phase 2 horde spawner. Spawns a rectangular block of zombies across all
# three lanes at the far end of the bridge. Lane-aware: each zombie is
# assigned a lane so the player can thin rows by shooting down that lane.

@export var zombie_scene: PackedScene
@export var zombies_per_lane: int = 14
@export var row_spacing: float = 1.4
@export var horde_front_z: float = -95.0


func _ready() -> void:
	call_deferred("_spawn_horde")


func _spawn_horde() -> void:
	if zombie_scene == null:
		return
	var total := zombies_per_lane * GameManager.LANE_COUNT
	GameManager.set_level_zombie_count(total)

	for lane_idx in GameManager.LANE_COUNT:
		for row in zombies_per_lane:
			var z := zombie_scene.instantiate()
			get_tree().current_scene.add_child(z)
			z.lane_index = lane_idx
			var x_jitter := randf_range(-0.4, 0.4)
			var z_jitter := randf_range(-0.3, 0.3)
			z.global_position = Vector3(
				GameManager.LANE_X_POSITIONS[lane_idx] + x_jitter,
				0.1,
				horde_front_z - row * row_spacing + z_jitter
			)
