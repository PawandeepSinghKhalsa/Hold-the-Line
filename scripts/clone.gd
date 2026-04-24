extends CharacterBody3D

# A squad clone. Follows the leader at a fixed local offset and auto-fires
# straight ahead at the same cadence as the leader. Clones have MAX_HP
# and die individually to zombie melee — losing a clone reduces squad
# size but doesn't end the run.

const FIRE_INTERVAL := 0.33
const BULLET_SPAWN_OFFSET := Vector3(0, 0.9, -0.3)
const FOLLOW_LERP_SPEED := 12.0
const MAX_HP := 30

@export var bullet_scene: PackedScene

var leader: Node3D
var follow_offset: Vector3 = Vector3.ZERO
var hp: int = MAX_HP
var _fire_cooldown: float = 0.0
var _dead: bool = false


func _ready() -> void:
	add_to_group("clones")
	hp = MAX_HP


func _physics_process(delta: float) -> void:
	if not GameManager.is_running or leader == null:
		velocity = Vector3.ZERO
		return

	var target_pos: Vector3 = leader.global_position + follow_offset
	var delta_vec: Vector3 = target_pos - global_position
	velocity = delta_vec * FOLLOW_LERP_SPEED

	move_and_slide()
	global_position.y = 0.1
	# Keep clones on the bridge even when the leader strafes to an edge lane.
	global_position.x = clamp(global_position.x, -2.1, 2.1)

	_fire_cooldown -= delta
	if _fire_cooldown <= 0.0:
		_fire_cooldown = GameManager.current_fire_interval(FIRE_INTERVAL)
		_shoot()


func _shoot() -> void:
	if bullet_scene == null:
		return
	var spawn_pos: Vector3 = global_position + BULLET_SPAWN_OFFSET
	_fire_for_active_weapon(spawn_pos)
	Effects.spawn_muzzle_flash(spawn_pos)


func _fire_for_active_weapon(spawn_pos: Vector3) -> void:
	match GameManager.active_weapon:
		GameManager.WEAPON_SHOTGUN:
			_fire_shotgun(spawn_pos)
		GameManager.WEAPON_SNIPER:
			_fire_sniper(spawn_pos)
		GameManager.WEAPON_ROCKET:
			_fire_rocket(spawn_pos)
		GameManager.WEAPON_LIGHTNING:
			_fire_lightning(spawn_pos)
		GameManager.WEAPON_FLAME:
			_fire_flame(spawn_pos)
		GameManager.WEAPON_RAILGUN:
			_fire_railgun(spawn_pos)
		GameManager.WEAPON_MACHINE_GUN:
			var dmg: int = int(GameManager.weapon_stat(GameManager.WEAPON_MACHINE_GUN, "damage", 1))
			_spawn_bullet(spawn_pos, Vector3(0.0, 0, -1.0), dmg, false)
		_:
			_spawn_bullet(spawn_pos, Vector3(0.0, 0, -1.0), 1, false)


func _fire_shotgun(spawn_pos: Vector3) -> void:
	var pellets: int = int(GameManager.weapon_stat(GameManager.WEAPON_SHOTGUN, "pellets", 3))
	var damage: int = int(GameManager.weapon_stat(GameManager.WEAPON_SHOTGUN, "damage", 1))
	pellets = max(pellets, 1)
	var spread: float = 0.24
	for i in pellets:
		var t: float = 0.5 if pellets <= 1 else float(i) / float(pellets - 1)
		var x: float = lerp(-spread, spread, t)
		var dir: Vector3 = Vector3(x, 0, -1).normalized()
		_spawn_bullet(spawn_pos, dir, damage, false)


func _fire_sniper(spawn_pos: Vector3) -> void:
	var damage: int = int(GameManager.weapon_stat(GameManager.WEAPON_SNIPER, "damage", 5))
	var lifetime_mult: float = float(GameManager.weapon_stat(GameManager.WEAPON_SNIPER, "lifetime_mult", 1.0))
	_spawn_bullet(spawn_pos, Vector3(0.0, 0, -1.0), damage, true, lifetime_mult)


func _fire_rocket(spawn_pos: Vector3) -> void:
	var bullet: Node3D = bullet_scene.instantiate() as Node3D
	if bullet == null:
		return
	var dmg: int = int(GameManager.weapon_stat(GameManager.WEAPON_ROCKET, "damage", 4))
	var radius: float = float(GameManager.weapon_stat(GameManager.WEAPON_ROCKET, "radius", 3.5))
	var aoe: int = int(GameManager.weapon_stat(GameManager.WEAPON_ROCKET, "aoe_damage", 4))
	bullet.set("direction", Vector3(0.0, 0, -1.0))
	bullet.set("damage_override", dmg)
	bullet.set("pierce_all", false)
	bullet.set("explosion_radius", radius)
	bullet.set("explosion_damage", aoe)
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = spawn_pos


func _fire_lightning(spawn_pos: Vector3) -> void:
	var bullet: Node3D = bullet_scene.instantiate() as Node3D
	if bullet == null:
		return
	bullet.set("direction", Vector3(0.0, 0, -1.0))
	bullet.set("damage_override", int(GameManager.weapon_stat(GameManager.WEAPON_LIGHTNING, "damage", 2)))
	bullet.set("pierce_all", false)
	bullet.set("chain_count", int(GameManager.weapon_stat(GameManager.WEAPON_LIGHTNING, "chain_count", 2)))
	bullet.set("chain_range", float(GameManager.weapon_stat(GameManager.WEAPON_LIGHTNING, "chain_range", 4.0)))
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = spawn_pos


func _fire_flame(spawn_pos: Vector3) -> void:
	var pellets: int = int(GameManager.weapon_stat(GameManager.WEAPON_FLAME, "pellets", 7))
	var damage: int = int(GameManager.weapon_stat(GameManager.WEAPON_FLAME, "damage", 1))
	pellets = max(pellets, 1)
	var spread: float = 0.45
	for i in pellets:
		var t: float = 0.5 if pellets <= 1 else float(i) / float(pellets - 1)
		var x: float = lerp(-spread, spread, t)
		var dir: Vector3 = Vector3(x, 0, -1).normalized()
		_spawn_bullet(spawn_pos, dir, damage, false, 0.25)


func _fire_railgun(spawn_pos: Vector3) -> void:
	var damage: int = int(GameManager.weapon_stat(GameManager.WEAPON_RAILGUN, "damage", 15))
	var life: float = float(GameManager.weapon_stat(GameManager.WEAPON_RAILGUN, "lifetime_mult", 2.0))
	_spawn_bullet(spawn_pos, Vector3(0.0, 0, -1.0), damage, true, life)


func _spawn_bullet(spawn_pos: Vector3, direction: Vector3, damage: int, pierce_all: bool, lifetime_mult: float = 1.0) -> void:
	var bullet: Node3D = bullet_scene.instantiate() as Node3D
	if bullet == null:
		return
	bullet.set("direction", direction)
	bullet.set("damage_override", damage)
	bullet.set("pierce_all", pierce_all)
	bullet.set("lifetime_multiplier", lifetime_mult)
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = spawn_pos


func take_damage(amount: int) -> void:
	if _dead:
		return
	hp = max(0, hp - amount)
	if hp <= 0:
		_dead = true
		Effects.spawn_zombie_death(global_position + Vector3(0, 0.75, 0))
		GameManager.on_clone_died()
		queue_free()
