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
const BASE_LIFETIME := 3.0
const HIT_RADIUS := 0.55
# Safety valve: if the scene is flooded with bullets (flamethrower +
# supercharge stacks can push this to 500+), despawn the oldest ones
# on spawn so the renderer never collapses under node pressure.
const MAX_ACTIVE_BULLETS := 90

var _age: float = 0.0
var _pierced: Dictionary = {}

@export var direction: Vector3 = Vector3(0, 0, -1)
@export var damage_override: int = 0  # 0 -> DEFAULT_DAMAGE
@export var pierce_all: bool = false
# Scales base bullet lifetime. Sniper tier 3 uses this for a slug that
# travels farther before despawning.
@export var lifetime_multiplier: float = 1.0
# When explosion_radius > 0 the bullet triggers an AOE on any impact,
# damaging every zombie within the sphere for explosion_damage.
@export var explosion_radius: float = 0.0
@export var explosion_damage: int = 0
# Lightning Gun: on hit, spawn a follow-up bullet aimed at the nearest
# other zombie within chain_range. chain_count decrements per chain.
@export var chain_count: int = 0
@export var chain_range: float = 0.0


func _ready() -> void:
	add_to_group("bullets")
	_enforce_bullet_cap()


func _enforce_bullet_cap() -> void:
	# Each bullet joins a "bullets" group on ready. If the group exceeds
	# MAX_ACTIVE_BULLETS, free the oldest entries so flamethrower spam
	# can't crash the renderer.
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var bullets: Array = tree.get_nodes_in_group("bullets")
	if bullets.size() <= MAX_ACTIVE_BULLETS:
		return
	var to_cull: int = bullets.size() - MAX_ACTIVE_BULLETS
	for i in to_cull:
		var old: Node = bullets[i]
		if old == self or old == null or not is_instance_valid(old):
			continue
		old.queue_free()


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= BASE_LIFETIME * max(lifetime_multiplier, 0.1):
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
			if chain_count > 0 and chain_range > 0.0:
				_chain_from(zombie_center, zombie)
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


# Spawn a follow-up lightning bolt aimed at the nearest unscorched zombie
# within chain_range of the impact. Decrements chain_count so the chain
# can only arc up to its configured length.
func _chain_from(pos: Vector3, just_hit: Node3D) -> void:
	var best: Node3D = null
	var best_dist: float = chain_range + 0.001
	for zombie_node in get_tree().get_nodes_in_group("zombies"):
		var zombie: Node3D = zombie_node as Node3D
		if zombie == null or not is_instance_valid(zombie):
			continue
		if zombie == just_hit:
			continue
		var zid: int = zombie.get_instance_id()
		if _pierced.has(zid):
			continue
		var zombie_center: Vector3 = zombie.global_position + Vector3(0, 0.75, 0)
		var d: float = pos.distance_to(zombie_center)
		if d < best_dist:
			best_dist = d
			best = zombie
	if best == null:
		return
	var next_center: Vector3 = best.global_position + Vector3(0, 0.75, 0)
	var dir: Vector3 = (next_center - pos).normalized()
	var chain_bullet: PackedScene = load("res://scenes/bullet.tscn") as PackedScene
	if chain_bullet == null:
		return
	var next: Node3D = chain_bullet.instantiate() as Node3D
	if next == null:
		return
	next.set("direction", dir)
	next.set("damage_override", damage_override)
	next.set("pierce_all", false)
	next.set("lifetime_multiplier", 0.6)
	next.set("chain_count", chain_count - 1)
	next.set("chain_range", chain_range)
	get_tree().current_scene.add_child(next)
	next.global_position = pos
