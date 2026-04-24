extends Node3D

# Spawns a rectangular block of zombies across the three lanes.
#
# - Back rows (controlled by `tough_rows_from_back`) get max_hp=`tough_hp`
#   so they take more bullets to drop.
# - Every 1-HP zombie has a `weak_ratio` chance of being marked `is_weak`,
#   which makes it smaller, paler, and pierceable by bullets (kill + the
#   bullet keeps flying through the rest of the lane).

@export var zombie_scene: PackedScene
@export var zombies_per_lane: int = 34
@export var row_spacing: float = 1.2
@export var horde_front_z: float = -95.0
@export var tough_rows_from_back: int = 0
@export var tough_hp: int = 2
@export_range(0.0, 1.0, 0.05) var weak_ratio: float = 0.0


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
			var is_tough: bool = row >= tough_threshold and tough_rows_from_back > 0
			# Set zombie properties before add_child so zombie._ready()
			# sees the right values when picking its tier.
			if is_tough:
				zombie.set("max_hp", tough_hp)
			elif weak_ratio > 0.0 and randf() < weak_ratio:
				zombie.set("is_weak", true)
			zombie.set("lane_index", lane_idx)
			get_tree().current_scene.add_child(zombie)
			var x_jitter: float = randf_range(-0.4, 0.4)
			var z_jitter: float = randf_range(-0.3, 0.3)
			zombie.global_position = Vector3(
				GameManager.LANE_X_POSITIONS[lane_idx] + x_jitter,
				0.1,
				horde_front_z - row * row_spacing + z_jitter
			)
