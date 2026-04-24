extends Node3D

# Drops weapon crates at random lanes a fixed distance ahead of the
# soldier at intervals. Every spawn randomly selects one of the three
# pickup weapons (shotgun / machine gun / sniper) so the bridge stays
# varied across a run.

@export var crate_scene: PackedScene
@export var spawn_interval: float = 10.0
@export var spawn_ahead: float = 14.0

var _timer: float = 6.0  # delay the first drop so the opener has no instant pickup
var _soldier: Node3D


func _process(delta: float) -> void:
	if _soldier == null:
		_soldier = get_tree().get_first_node_in_group("soldier") as Node3D
		if _soldier == null:
			return
	if not GameManager.is_running:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = spawn_interval
		_spawn_crate()


func _spawn_crate() -> void:
	if crate_scene == null or _soldier == null:
		return
	var crate_node: Node = crate_scene.instantiate()
	var crate: Node3D = crate_node as Node3D
	if crate == null:
		return
	var lane: int = randi() % GameManager.LANE_COUNT
	var lane_x: float = GameManager.LANE_X_POSITIONS[lane]
	var spawn_z: float = _soldier.global_position.z - spawn_ahead
	var weapon_choices: Array = [
		GameManager.WEAPON_SHOTGUN,
		GameManager.WEAPON_MACHINE_GUN,
		GameManager.WEAPON_SNIPER,
	]
	crate.set("weapon_id", weapon_choices[randi() % weapon_choices.size()])
	get_tree().current_scene.add_child(crate)
	crate.global_position = Vector3(lane_x, 0.0, spawn_z)
