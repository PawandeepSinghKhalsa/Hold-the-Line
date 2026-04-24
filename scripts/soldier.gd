extends CharacterBody3D

# Auto-walks forward on one of 3 lanes. Auto-fires bullets straight ahead
# every FIRE_INTERVAL seconds. Player controls only lane via keyboard or
# tap on left/right half of screen.

signal lane_changed(new_lane: int)

const LANE_LERP_SPEED := 12.0
const FIRE_INTERVAL := 0.5
const BULLET_SPAWN_OFFSET := Vector3(0, 0.9, -0.5)

@export var bullet_scene: PackedScene

var lane_index: int = 1
var _fire_cooldown: float = 0.0


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

	_fire_cooldown -= delta
	if _fire_cooldown <= 0.0:
		_fire_cooldown = FIRE_INTERVAL
		_shoot()


func _shoot() -> void:
	if bullet_scene == null:
		return
	var bullet := bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position + BULLET_SPAWN_OFFSET


func _try_change_lane(delta_index: int) -> void:
	var new_lane: int = clamp(lane_index + delta_index, 0, GameManager.LANE_COUNT - 1)
	if new_lane != lane_index:
		lane_index = new_lane
		lane_changed.emit(lane_index)


func take_melee_hit() -> void:
	GameManager.end_run(false)
