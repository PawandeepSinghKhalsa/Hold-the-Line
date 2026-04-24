extends CharacterBody3D

# Actively chases the soldier. Each frame the zombie steers toward the
# soldier's current XZ position. Melee contact uses a 2D (XZ) distance
# check to avoid Y drift hiding the game-over trigger.

const WALK_SPEED := 3.0
const MELEE_RANGE := 0.9
# Extra multiplier on the lateral component of the chase vector so zombies
# from outer lanes visibly peel toward the soldier's lane.
const LATERAL_GAIN := 1.4

@export var max_hp: int = 1
var hp: int
var lane_index: int = 1
var _target_jitter: Vector3 = Vector3.ZERO


func _ready() -> void:
	hp = max_hp
	add_to_group("zombies")
	_target_jitter = Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-0.4, 0.4))
	_apply_tough_appearance_if_needed()


func _apply_tough_appearance_if_needed() -> void:
	# Tough zombies (max_hp >= 2) get a darker body so the player can spot
	# them and prioritise. Duplicate the material so each instance owns
	# its override colour.
	if max_hp < 2:
		return
	var mesh_node: Node = get_node_or_null("Mesh")
	var mesh_instance: MeshInstance3D = mesh_node as MeshInstance3D
	if mesh_instance == null or mesh_instance.material_override == null:
		return
	var unique_material: Material = mesh_instance.material_override.duplicate() as Material
	mesh_instance.material_override = unique_material
	var standard_mat: StandardMaterial3D = unique_material as StandardMaterial3D
	if standard_mat == null:
		return
	if max_hp >= 3:
		standard_mat.albedo_color = Color(0.35, 0.08, 0.15, 1)
	else:
		standard_mat.albedo_color = Color(0.55, 0.12, 0.18, 1)


func _physics_process(_delta: float) -> void:
	if not GameManager.is_running:
		velocity = Vector3.ZERO
		return

	var soldier: Node3D = get_tree().get_first_node_in_group("soldier") as Node3D
	if soldier == null:
		velocity = Vector3(0, 0, WALK_SPEED)
	else:
		var target: Vector3 = soldier.global_position + _target_jitter
		var to_target: Vector3 = target - global_position
		to_target.y = 0.0
		if to_target.length() > 0.05:
			var dir: Vector3 = to_target.normalized()
			velocity = dir * WALK_SPEED
			velocity.x *= LATERAL_GAIN
		else:
			velocity = Vector3.ZERO

	move_and_slide()
	global_position.y = 0.1

	if soldier != null:
		var me: Vector2 = Vector2(global_position.x, global_position.z)
		var target_pos: Vector2 = Vector2(soldier.global_position.x, soldier.global_position.z)
		if me.distance_to(target_pos) < MELEE_RANGE:
			if soldier.has_method("take_melee_hit"):
				soldier.take_melee_hit()


func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		GameManager.on_zombie_killed()
		queue_free()
