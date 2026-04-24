extends Area3D

# Travels straight forward (-Z) from the soldier. Uses a distance check
# against the zombies group every physics tick.
#
# Bullets pierce through weak zombies (is_weak=true) — they kill the
# weak zombie and continue forward. Hitting any non-weak zombie stops
# the bullet.

const SPEED := 25.0
const DAMAGE := 1
const LIFETIME := 3.0
const HIT_RADIUS := 0.55

var _age: float = 0.0
var _pierced: Dictionary = {}


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
		var zid: int = zombie.get_instance_id()
		if _pierced.has(zid):
			continue
		var zombie_center: Vector3 = zombie.global_position + Vector3(0, 0.75, 0)
		if global_position.distance_to(zombie_center) < HIT_RADIUS:
			var is_weak: bool = zombie.get("is_weak") if "is_weak" in zombie else false
			Effects.spawn_bullet_impact(zombie_center)
			if zombie.has_method("take_damage"):
				zombie.take_damage(DAMAGE)
			_pierced[zid] = true
			if not is_weak:
				queue_free()
				return
			# Keep flying and hit the next target this frame / next frames.
