extends Area3D

# Travels along `direction` at SPEED. Uses a distance check against the
# zombies group every physics tick instead of Area3D signals.
#
# Bullets can optionally:
#   - pierce through weak zombies (default — kills them and continues)
#   - pierce through EVERY zombie (sniper / special weapons) — kills
#     but never despawns on hit
#
# Damage defaults to 1 but shotgun / sniper shots can override it by
# setting `damage_override` at spawn time.

const SPEED := 25.0
const DEFAULT_DAMAGE := 1
const LIFETIME := 3.0
const HIT_RADIUS := 0.55

var _age: float = 0.0
var _pierced: Dictionary = {}

@export var direction: Vector3 = Vector3(0, 0, -1)
@export var damage_override: int = 0  # 0 -> DEFAULT_DAMAGE
@export var pierce_all: bool = false
# When explosion_radius > 0 the bullet triggers an AOE on any impact,
# damaging every zombie within the sphere for explosion_damage.
@export var explosion_radius: float = 0.0
@export var explosion_damage: int = 0


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	global_position += direction * SPEED * delta

	var dmg: int = damage_override if damage_override > 0 else DEFAULT_DAMAGE

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
				zombie.take_damage(dmg)
			_pierced[zid] = true
			if explosion_radius > 0.0:
				_explode_at(global_position)
				queue_free()
				return
			if pierce_all or is_weak:
				continue
			queue_free()
			return


func _explode_at(pos: Vector3) -> void:
	var aoe_damage: int = explosion_damage if explosion_damage > 0 else 3
	for zombie_node in get_tree().get_nodes_in_group("zombies"):
		var zombie: Node3D = zombie_node as Node3D
		if zombie == null or not is_instance_valid(zombie):
			continue
		var zombie_center: Vector3 = zombie.global_position + Vector3(0, 0.75, 0)
		if pos.distance_to(zombie_center) <= explosion_radius:
			if zombie.has_method("take_damage"):
				zombie.take_damage(aoe_damage)
	Effects.spawn_explosion(pos, explosion_radius)
