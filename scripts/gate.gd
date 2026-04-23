extends Node3D

# Split gate. Player strafes into one half:
# - Left half (blue): upgrades weapon tier
# - Right half (magenta): multiplies squad size and spawns clones

@export var squad_multiplier: int = 2
@export var weapon_upgrade_steps: int = 1
@export var clone_scene: PackedScene

var _consumed: bool = false


func _ready() -> void:
	var left: Area3D = $LeftHalf
	var right: Area3D = $RightHalf
	left.body_entered.connect(_on_left_entered)
	right.body_entered.connect(_on_right_entered)
	if left.has_node("Label"):
		left.get_node("Label").text = "WEAPON +%d" % weapon_upgrade_steps
	if right.has_node("Label"):
		right.get_node("Label").text = "x%d SQUAD" % squad_multiplier


func _on_left_entered(body: Node3D) -> void:
	if _consumed or not body.is_in_group("soldier"):
		return
	_consumed = true
	GameManager.upgrade_weapon(weapon_upgrade_steps)
	queue_free()


func _on_right_entered(body: Node3D) -> void:
	if _consumed or not body.is_in_group("soldier"):
		return
	_consumed = true
	var spawned := GameManager.apply_multiplier(squad_multiplier)
	_spawn_clones(body, spawned)
	queue_free()


func _spawn_clones(leader: Node3D, count: int) -> void:
	if clone_scene == null or count <= 0:
		return
	for i in count:
		var clone := clone_scene.instantiate()
		get_tree().current_scene.add_child(clone)
		var angle := (TAU / max(count, 1)) * i
		var offset := Vector3(cos(angle) * 1.2, 0, sin(angle) * 1.2)
		clone.global_position = leader.global_position + offset
		clone.leader = leader
		clone.add_to_group("clones")
