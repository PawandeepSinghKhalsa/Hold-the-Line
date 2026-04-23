extends Node3D

# Spawns waves of zombies ahead of the soldier and points them at the leader.

@export var zombie_scene: PackedScene
@export var spawn_interval: float = 1.5
@export var spawn_distance_ahead: float = 15.0
@export var spawn_lateral_spread: float = 1.8
@export var zombies_per_wave: int = 3

var leader: Node3D
var _timer: float = 0.0


func _process(delta: float) -> void:
	if leader == null:
		var soldiers := get_tree().get_nodes_in_group("soldier")
		if soldiers.size() > 0:
			leader = soldiers[0]
	if leader == null or zombie_scene == null:
		return
	if not GameManager.is_running:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = spawn_interval
		_spawn_wave()


func _spawn_wave() -> void:
	for i in zombies_per_wave:
		var z := zombie_scene.instantiate()
		get_tree().current_scene.add_child(z)
		var x := randf_range(-spawn_lateral_spread, spawn_lateral_spread)
		z.global_position = leader.global_position + Vector3(x, 0, -spawn_distance_ahead)
		z.target = leader
