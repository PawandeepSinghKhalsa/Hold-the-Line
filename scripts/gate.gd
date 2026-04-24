extends Node3D

# Split gate. Each half has an operation (mul, add, sub, div) and a value.
# When the soldier's Z crosses the gate's Z, the sign of their X relative
# to the gate centre picks which half fires.
#
# Operations:
#   mul N: squad *= N  (multiplicative, prints as "xN")
#   add N: squad += N  (additive, prints as "+N")
#   sub N: squad -= N  (penalty, prints as "-N")
#   div N: squad /= N  (halving-style, prints as "/N")
#
# Positive deltas spawn new clones at the next free formation slots;
# negative deltas despawn clones starting from the back of the formation
# so the squad compacts toward the leader rather than leaving gaps.

@export var left_op: String = "mul"
@export var left_value: int = 2
@export var right_op: String = "mul"
@export var right_value: int = 3
@export var clone_scene: PackedScene
# When true, left_op/right_op/left_value/right_value are re-rolled at
# _ready using one of four combo templates: pos/neg, neg/pos, pos/pos,
# neg/neg. Gives every run a slightly different gate layout.
@export var random_combo: bool = false

const TRIGGER_DEPTH := 0.6
const POS_MIN := 3
const POS_MAX := 10
const NEG_MIN := 3
const NEG_MAX := 7

var _consumed: bool = false
var _soldier: Node3D = null


func _ready() -> void:
	if random_combo:
		_randomize_combo()
	if has_node("LeftHalf/Label"):
		(get_node("LeftHalf/Label") as Label3D).text = _format_label(left_op, left_value)
	if has_node("RightHalf/Label"):
		(get_node("RightHalf/Label") as Label3D).text = _format_label(right_op, right_value)


func _randomize_combo() -> void:
	var combo: int = randi_range(0, 3)
	match combo:
		0:  # pos / neg
			left_op = "add"
			left_value = randi_range(POS_MIN, POS_MAX)
			right_op = "sub"
			right_value = randi_range(NEG_MIN, NEG_MAX)
		1:  # neg / pos
			left_op = "sub"
			left_value = randi_range(NEG_MIN, NEG_MAX)
			right_op = "add"
			right_value = randi_range(POS_MIN, POS_MAX)
		2:  # pos / pos (different values)
			left_op = "add"
			left_value = randi_range(POS_MIN, POS_MAX)
			right_op = "add"
			right_value = _different_value(left_value, POS_MIN, POS_MAX)
		_:  # neg / neg (different values)
			left_op = "sub"
			left_value = randi_range(NEG_MIN, NEG_MAX)
			right_op = "sub"
			right_value = _different_value(left_value, NEG_MIN, NEG_MAX)


func _different_value(avoid: int, lo: int, hi: int) -> int:
	var v: int = randi_range(lo, hi)
	# Two-try loop is plenty for small ranges; if everything collides just
	# accept the duplicate — the player still has a valid choice.
	if v == avoid:
		v = randi_range(lo, hi)
	return v


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
	if dx < 0.0:
		_apply(_soldier, left_op, left_value)
	else:
		_apply(_soldier, right_op, right_value)
	queue_free()


func _apply(leader: Node3D, op: String, value: int) -> void:
	var before: int = GameManager.squad_size
	var delta: int = 0
	match op:
		"add":
			delta = GameManager.apply_add(value)
		"sub":
			delta = GameManager.apply_sub(value)
		"div":
			delta = GameManager.apply_div(value)
		_:
			delta = GameManager.apply_multiplier(value)

	if delta > 0:
		_spawn_clones(leader, before, delta)
	elif delta < 0:
		_despawn_clones(-delta)


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
		clone.set("leader", leader)
		clone.set("follow_offset", offset)
		clone.global_position = leader.global_position + offset


func _despawn_clones(count: int) -> void:
	if count <= 0:
		return
	var clones: Array = get_tree().get_nodes_in_group("clones")
	# Remove the backmost clones first so the formation compacts from behind.
	clones.sort_custom(func(a, b): return a.follow_offset.z > b.follow_offset.z)
	var to_remove: int = min(count, clones.size())
	for i in to_remove:
		clones[i].queue_free()


func _format_label(op: String, value: int) -> String:
	match op:
		"add":
			return "+%d" % value
		"sub":
			return "-%d" % value
		"div":
			return "/%d" % value
		_:
			return "x%d" % value
