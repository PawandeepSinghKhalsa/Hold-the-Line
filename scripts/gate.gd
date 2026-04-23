extends Area3D

# Multiplier gate. When the soldier enters, squad size is multiplied and
# new clones are spawned. Gate is then consumed.

@export var multiplier: int = 2
@export var clone_scene: PackedScene

var _consumed: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _consumed:
		return
	if not body.is_in_group("soldier"):
		return
	_consumed = true
	var spawned := GameManager.apply_multiplier(multiplier)
	_spawn_clones(body, spawned)
	queue_free()


func _spawn_clones(leader: Node3D, count: int) -> void:
	if clone_scene == null or count <= 0:
		return
	for i in count:
		var clone := clone_scene.instantiate()
		get_tree().current_scene.add_child(clone)
		var angle := (TAU / count) * i
		var offset := Vector3(cos(angle) * 1.2, 0, sin(angle) * 1.2)
		clone.global_position = leader.global_position + offset
		clone.leader = leader
		clone.add_to_group("clones")
