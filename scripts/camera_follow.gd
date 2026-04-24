extends Camera3D

# Follows the soldier on Z only. Keeps X centred so all 3 lanes are visible
# without the camera sliding when the soldier changes lanes. Subscribes to
# the Effects autoload's screen shake signal and adds a decaying random
# offset on top of the follow position while a shake is active.

@export var target_path: NodePath
@export var height: float = 4.5
@export var distance_behind: float = 7.0

var _target: Node3D
var _shake_intensity: float = 0.0
var _shake_total_time: float = 0.0
var _shake_time_left: float = 0.0


func _ready() -> void:
	if target_path:
		_target = get_node(target_path)
	Effects.screen_shake_requested.connect(_on_shake_requested)


func _on_shake_requested(intensity: float, duration: float) -> void:
	# A new shake stacks: keep the larger of either dimension so a small
	# follow-up shake during a big one doesn't truncate it.
	if intensity > _shake_intensity:
		_shake_intensity = intensity
	if duration > _shake_time_left:
		_shake_time_left = duration
		_shake_total_time = duration


func _process(delta: float) -> void:
	if _target == null:
		return
	var base: Vector3 = Vector3(
		0.0,
		_target.global_position.y + height,
		_target.global_position.z + distance_behind
	)

	if _shake_time_left > 0.0:
		_shake_time_left = max(0.0, _shake_time_left - delta)
		var falloff: float = _shake_time_left / max(_shake_total_time, 0.001)
		var offset: Vector3 = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			0.0
		) * _shake_intensity * falloff
		global_position = base + offset
		if _shake_time_left == 0.0:
			_shake_intensity = 0.0
			_shake_total_time = 0.0
	else:
		global_position = base
