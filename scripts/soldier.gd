extends CharacterBody3D

# Auto-runs forward. Player controls only lateral strafe (A/D or arrows).
# Auto-fires at nearest zombie like a clone. Dies if pushed off bridge edges.

@export var bullet_scene: PackedScene

var _fire_cooldown: float = 0.0


func _ready() -> void:
	GameManager.reset()
	add_to_group("shooters")


func _physics_process(delta: float) -> void:
	if not GameManager.is_running:
		velocity = Vector3.ZERO
		return

	var lateral := Input.get_axis("move_left", "move_right")
	velocity.x = lateral * GameManager.STRAFE_SPEED
	velocity.z = -GameManager.FORWARD_SPEED

	move_and_slide()

	position.x = clamp(position.x, -GameManager.BRIDGE_HALF_WIDTH, GameManager.BRIDGE_HALF_WIDTH)
	GameManager.distance_traveled = max(GameManager.distance_traveled, -position.z)

	_fire_cooldown -= delta
	if _fire_cooldown <= 0.0:
		_try_shoot()
		_fire_cooldown = 1.0 / GameManager.weapon_fire_rate()


func _try_shoot() -> void:
	if bullet_scene == null:
		return
	var target := _find_nearest_zombie()
	if target == null:
		return
	var bullet := bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position + Vector3(0, 0.6, 0)
	bullet.direction = (target.global_position - bullet.global_position).normalized()


func _find_nearest_zombie() -> Node3D:
	var zombies := get_tree().get_nodes_in_group("zombies")
	var best: Node3D = null
	var best_dist := INF
	for z in zombies:
		var d: float = global_position.distance_to(z.global_position)
		if d < best_dist:
			best_dist = d
			best = z
	return best


func take_melee_hit() -> void:
	GameManager.kill_leader()
