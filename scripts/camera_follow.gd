extends Camera3D

# Follows the soldier on Z only. Keeps X centered so all 3 lanes are visible
# without the camera sliding when the soldier changes lanes.

@export var target_path: NodePath
@export var height: float = 4.5
@export var distance_behind: float = 7.0

var _target: Node3D


func _ready() -> void:
	if target_path:
		_target = get_node(target_path)


func _process(_delta: float) -> void:
	if _target == null:
		return
	global_position = Vector3(
		0.0,
		_target.global_position.y + height,
		_target.global_position.z + distance_behind
	)
