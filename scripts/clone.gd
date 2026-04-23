extends CharacterBody3D

# A squad member. Follows the soldier with an offset, shoots the nearest zombie
# on a fixed cadence. Dies when a zombie touches it in melee range.

@export var follow_offset: Vector3 = Vector3(0, 0, 1.0)
@export var fire_rate: float = 1.0
@export var bullet_scene: PackedScene
@export var melee_damage_interval: float = 2.0

var leader: Node3D
var _fire_cooldown: float = 0.0
var _melee_cooldown: float = 0.0


func _physics_process(delta: float) -> void:
	if leader == null:
		return

	var target_pos := leader.global_position + follow_offset
	var to_target := target_pos - global_position
	velocity = to_target * 8.0
	move_and_slide()

	_fire_cooldown -= delta
	if _fire_cooldown <= 0.0:
		_try_shoot()
		_fire_cooldown = 1.0 / fire_rate

	_melee_cooldown = max(0.0, _melee_cooldown - delta)


func _try_shoot() -> void:
	if bullet_scene == null:
		return
	var target := _find_nearest_zombie()
	if target == null:
		return
	var bullet := bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position + Vector3(0, 0.5, 0)
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
	if _melee_cooldown > 0.0:
		return
	_melee_cooldown = melee_damage_interval
	GameManager.remove_clone()
	queue_free()
