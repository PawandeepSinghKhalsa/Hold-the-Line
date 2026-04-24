extends CharacterBody3D

# Auto-walks forward on one of 3 lanes. Player switches lanes via:
# - Keyboard: A/D or Left/Right (discrete, on just_pressed)
# - Touch/mouse: tap on left or right half of screen
# Lateral transition between lanes uses linear interpolation (not snap).

signal lane_changed(new_lane: int)

const LANE_LERP_SPEED := 12.0

var lane_index: int = 1


func _ready() -> void:
	GameManager.reset()
	add_to_group("soldier")


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_running:
		return
	if event is InputEventScreenTouch and event.pressed:
		_handle_screen_tap(event.position.x)


func _handle_screen_tap(screen_x: float) -> void:
	var half_width := get_viewport().get_visible_rect().size.x / 2.0
	if screen_x < half_width:
		_try_change_lane(-1)
	else:
		_try_change_lane(1)


func _physics_process(delta: float) -> void:
	if not GameManager.is_running:
		velocity = Vector3.ZERO
		return

	if Input.is_action_just_pressed("move_left"):
		_try_change_lane(-1)
	if Input.is_action_just_pressed("move_right"):
		_try_change_lane(1)

	var target_x: float = GameManager.LANE_X_POSITIONS[lane_index]
	var dx := target_x - position.x
	velocity.x = dx * LANE_LERP_SPEED
	velocity.z = -GameManager.FORWARD_SPEED

	move_and_slide()


func _try_change_lane(delta_index: int) -> void:
	var new_lane: int = clamp(lane_index + delta_index, 0, GameManager.LANE_COUNT - 1)
	if new_lane != lane_index:
		lane_index = new_lane
		lane_changed.emit(lane_index)
