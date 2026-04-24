extends CharacterBody3D

# Actively chases the soldier. Each frame the zombie steers toward the
# soldier's current XZ position. Melee contact uses a 2D (XZ) distance
# check to avoid Y drift hiding the game-over trigger.

const WALK_SPEED := 3.0
const MELEE_RANGE := 0.9
# Extra multiplier on the lateral component of the chase vector so zombies
# from outer lanes visibly peel toward the soldier's lane.
const LATERAL_GAIN := 1.4
# HP thresholds that promote a zombie into boss tier: bigger, slower,
# and coloured differently so the player sees them coming.
const BOSS_HP_THRESHOLD := 20

@export var max_hp: int = 1
var hp: int
var lane_index: int = 1
var _target_jitter: Vector3 = Vector3.ZERO
var _walk_speed: float = WALK_SPEED
var _melee_range: float = MELEE_RANGE


func _ready() -> void:
	hp = max_hp
	add_to_group("zombies")
	if max_hp >= BOSS_HP_THRESHOLD:
		add_to_group("bosses")
		_walk_speed = WALK_SPEED * 0.55
		_melee_range = MELEE_RANGE * 1.7
	_target_jitter = Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-0.4, 0.4))
	_apply_tough_appearance_if_needed()


func _apply_tough_appearance_if_needed() -> void:
	# Tough zombies (max_hp >= 2) get a darker body and a taller capsule
	# so the player can spot and prioritise them. Bosses (max_hp >=
	# BOSS_HP_THRESHOLD) scale wider AND taller and wear a distinct
	# purple-black colour so they read as a finale. Material is
	# duplicated per instance so colour changes don't leak to other
	# zombies.
	if max_hp < 2:
		return

	var height_scale: float = 1.3
	var width_scale: float = 1.0
	var albedo: Color = Color(0.55, 0.12, 0.18, 1)

	if max_hp >= BOSS_HP_THRESHOLD:
		height_scale = 2.4
		width_scale = 1.9
		albedo = Color(0.28, 0.08, 0.42, 1)
	elif max_hp >= 3:
		height_scale = 1.55
		albedo = Color(0.35, 0.08, 0.15, 1)

	# Base capsule: radius 0.3, height 1.5, positioned at local y=0.75 so
	# the feet sit at y=0. When we scale along Y the centre needs to move
	# up by half the added height so the feet stay planted on the bridge.
	var base_height: float = 1.5
	var base_center_y: float = 0.75
	var lifted_center_y: float = base_center_y + base_height * 0.5 * (height_scale - 1.0)
	var scale_vec: Vector3 = Vector3(width_scale, height_scale, width_scale)

	var mesh_node: Node = get_node_or_null("Mesh")
	var mesh_instance: MeshInstance3D = mesh_node as MeshInstance3D
	if mesh_instance != null:
		mesh_instance.scale = scale_vec
		mesh_instance.position = Vector3(0, lifted_center_y, 0)
		if mesh_instance.material_override != null:
			var unique_material: Material = mesh_instance.material_override.duplicate() as Material
			mesh_instance.material_override = unique_material
			var standard_mat: StandardMaterial3D = unique_material as StandardMaterial3D
			if standard_mat != null:
				standard_mat.albedo_color = albedo
				if max_hp >= BOSS_HP_THRESHOLD:
					standard_mat.emission_enabled = true
					standard_mat.emission = Color(0.55, 0.15, 0.8, 1)
					standard_mat.emission_energy_multiplier = 0.4

	var collision_node: Node = get_node_or_null("CollisionShape3D")
	var collision_shape: CollisionShape3D = collision_node as CollisionShape3D
	if collision_shape != null:
		collision_shape.scale = scale_vec
		collision_shape.position = Vector3(0, lifted_center_y, 0)


func _physics_process(_delta: float) -> void:
	if not GameManager.is_running:
		velocity = Vector3.ZERO
		return

	var soldier: Node3D = get_tree().get_first_node_in_group("soldier") as Node3D
	if soldier == null:
		velocity = Vector3(0, 0, _walk_speed)
	else:
		var target: Vector3 = soldier.global_position + _target_jitter
		var to_target: Vector3 = target - global_position
		to_target.y = 0.0
		if to_target.length() > 0.05:
			var dir: Vector3 = to_target.normalized()
			velocity = dir * _walk_speed
			velocity.x *= LATERAL_GAIN
		else:
			velocity = Vector3.ZERO

	move_and_slide()
	global_position.y = 0.1

	if soldier != null:
		var me: Vector2 = Vector2(global_position.x, global_position.z)
		var target_pos: Vector2 = Vector2(soldier.global_position.x, soldier.global_position.z)
		if me.distance_to(target_pos) < _melee_range:
			if soldier.has_method("take_melee_hit"):
				soldier.take_melee_hit()


func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		GameManager.on_zombie_killed()
		queue_free()
