extends Node3D

# Split gate. Polls the soldier's position each frame instead of relying on
# Area3D body_entered (which proved unreliable in the web export during
# Phase 2). When the soldier's Z crosses the gate's Z, the side of the
# soldier's X relative to the gate's centre determines which multiplier
# fires, and the gate consumes itself.

@export var left_multiplier: int = 2
@export var right_multiplier: int = 3
@export var clone_scene: PackedScene

const TRIGGER_DEPTH := 0.6

var _consumed: bool = false
var _soldier: Node3D = null


func _ready() -> void:
	if has_node("LeftHalf/Label"):
		(get_node("LeftHalf/Label") as Label3D).text = "x%d" % left_multiplier
	if has_node("RightHalf/Label"):
		(get_node("RightHalf/Label") as Label3D).text = "x%d" % right_multiplier


func _process(_delta: float) -> void:
	if _consumed:
		return
	if _soldier == null:
		_soldier = get_tree().get_first_node_in_group("soldier") as Node3D
		if _soldier == null:
			return

	var dz: float = _soldier.global_position.z - global_position.z
	if abs(dz) > TRIGGER_DEPTH:
		return

	_consumed = true
	var dx: float = _soldier.global_position.x - global_position.x
	var multiplier: int = left_multiplier if dx < 0.0 else right_multiplier
	_apply(_soldier, multiplier)
	queue_free()


func _apply(leader: Node3D, multiplier: int) -> void:
	var before: int = GameManager.squad_size
	var spawned_count: int = GameManager.apply_multiplier(multiplier)
	_spawn_clones(leader, before, spawned_count)


func _spawn_clones(leader: Node3D, previous_squad_size: int, count: int) -> void:
	if clone_scene == null or count <= 0:
		return
	for i in count:
		var clone_node: Node = clone_scene.instantiate()
		var clone: CharacterBody3D = clone_node as CharacterBody3D
		if clone == null:
			continue
		get_tree().current_scene.add_child(clone)
		var clone_index_in_squad: int = (previous_squad_size - 1) + i
		var offset: Vector3 = GameManager.clone_offset_for_index(clone_index_in_squad)
		clone.leader = leader
		clone.follow_offset = offset
		clone.global_position = leader.global_position + offset
