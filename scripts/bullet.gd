extends Area3D

# Travels straight forward (-Z) from the soldier. Uses a distance check
# against the zombies group every physics tick.

const SPEED := 25.0
const DAMAGE := 1
const LIFETIME := 3.0
const HIT_RADIUS := 0.55

var _age: float = 0.0


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	global_position.z -= SPEED * delta

	for zombie_node in get_tree().get_nodes_in_group("zombies"):
		var zombie: Node3D = zombie_node as Node3D
		if zombie == null or not is_instance_valid(zombie):
			continue
		var zombie_center: Vector3 = zombie.global_position + Vector3(0, 0.75, 0)
		if global_position.distance_to(zombie_center) < HIT_RADIUS:
			Effects.spawn_bullet_impact(zombie_center)
			if zombie.has_method("take_damage"):
				zombie.take_damage(DAMAGE)
			queue_free()
			return
