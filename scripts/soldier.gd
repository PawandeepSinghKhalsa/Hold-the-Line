extends CharacterBody3D

# The leader the camera follows. Lateral input from the player; forward/back
# drift comes from the push-back tug-of-war computed in GameManager.

@export var lateral_speed: float = 6.0


func _ready() -> void:
	GameManager.reset()


func _physics_process(delta: float) -> void:
	if not GameManager.is_running:
		velocity = Vector3.ZERO
		return

	var lateral := Input.get_axis("move_left", "move_right")
	velocity.x = lateral * lateral_speed
	velocity.x = clamp(velocity.x, -lateral_speed, lateral_speed)

	var active_zombies := get_tree().get_nodes_in_group("zombies").size()
	var net_force := GameManager.compute_net_push(active_zombies)
	velocity.z = net_force * GameManager.PUSH_SPEED_SCALE

	move_and_slide()

	position.x = clamp(position.x, -GameManager.BRIDGE_HALF_WIDTH, GameManager.BRIDGE_HALF_WIDTH)
	GameManager.distance_traveled = max(GameManager.distance_traveled, -position.z)

	if Input.is_action_just_pressed("supercharge"):
		GameManager.try_trigger_supercharge()
