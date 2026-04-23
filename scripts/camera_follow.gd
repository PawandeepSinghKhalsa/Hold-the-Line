extends Camera3D

# Follows target on Z only (no lateral slide when soldier strafes).

@export var target_path: NodePath
@export var offset: Vector3 = Vector3(0, 5, 7)

var _target: Node3D


func _ready() -> void:
	if target_path:
		_target = get_node(target_path)


func _process(_delta: float) -> void:
	if _target == null:
		return
	global_position = Vector3(0, _target.global_position.y + offset.y, _target.global_position.z + offset.z)
