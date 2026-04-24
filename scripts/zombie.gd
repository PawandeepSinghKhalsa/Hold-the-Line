extends CharacterBody3D

# Actively chases the soldier. Each frame the zombie steers toward the
# soldier's current XZ position. Melee contact deals damage-per-second
# (tier-dependent) to whichever target is closest within MELEE_RANGE,
# instead of instant-killing the leader.
#
# Tiers (derived from max_hp and is_weak):
#   weak     : smaller, pale pink, low DPS, 1 HP; bullets pierce through
#   regular  : default red, 1 HP, medium DPS
#   tough    : 2 HP, taller + darker, higher DPS
#   boss     : >= BOSS_HP_THRESHOLD, huge purple, highest DPS, slow chase

const WALK_SPEED := 3.0
const MELEE_RANGE := 0.9
# Extra multiplier on the lateral component of the chase vector so zombies
# from outer lanes visibly peel toward the soldier's lane.
const LATERAL_GAIN := 1.4
const BOSS_HP_THRESHOLD := 20

@export var max_hp: int = 1
@export var is_weak: bool = false
var hp: int
var lane_index: int = 1
var damage_per_second: float = 10.0
var _target_jitter: Vector3 = Vector3.ZERO
var _walk_speed: float = WALK_SPEED
var _melee_range: float = MELEE_RANGE
var _dead: bool = false
var _hp_bar_fill_mesh: QuadMesh = null
var _hp_bar_fill: MeshInstance3D = null
var _hp_bar_max_width: float = 3.0


func _ready() -> void:
	hp = max_hp
	add_to_group("zombies")
	_configure_tier()
	_target_jitter = Vector3(randf_range(-0.8, 0.8), 0.0, randf_range(-0.4, 0.4))
	_apply_appearance()
	if max_hp >= BOSS_HP_THRESHOLD:
		_create_boss_hp_bar()


func _configure_tier() -> void:
	if max_hp >= BOSS_HP_THRESHOLD:
		add_to_group("bosses")
		_walk_speed = WALK_SPEED * 0.55
		_melee_range = MELEE_RANGE * 1.7
		damage_per_second = 40.0
	elif max_hp >= 2:
		damage_per_second = 18.0
	elif is_weak:
		damage_per_second = 5.0
	else:
		damage_per_second = 10.0


func _apply_appearance() -> void:
	# Weak zombies are smaller and paler; tough zombies grow and darken;
	# boss zombies grow big, turn purple, and glow. Each tier duplicates
	# the shared material so per-instance colour changes don't leak.
	var height_scale: float = 1.0
	var width_scale: float = 1.0
	var albedo: Color = Color(0.85, 0.25, 0.25, 1)
	var want_glow: bool = false

	if max_hp >= BOSS_HP_THRESHOLD:
		height_scale = 2.4
		width_scale = 1.9
		albedo = Color(0.28, 0.08, 0.42, 1)
		want_glow = true
	elif max_hp >= 3:
		height_scale = 1.55
		albedo = Color(0.35, 0.08, 0.15, 1)
	elif max_hp >= 2:
		height_scale = 1.3
		albedo = Color(0.55, 0.12, 0.18, 1)
	elif is_weak:
		height_scale = 0.85
		width_scale = 0.85
		albedo = Color(1.0, 0.55, 0.65, 1)

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
				if want_glow:
					standard_mat.emission_enabled = true
					standard_mat.emission = Color(0.55, 0.15, 0.8, 1)
					standard_mat.emission_energy_multiplier = 0.4

	var collision_node: Node = get_node_or_null("CollisionShape3D")
	var collision_shape: CollisionShape3D = collision_node as CollisionShape3D
	if collision_shape != null:
		collision_shape.scale = scale_vec
		collision_shape.position = Vector3(0, lifted_center_y, 0)


func _physics_process(delta: float) -> void:
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

	if soldier == null:
		return

	# Damage the closest squad member (leader or clone) in melee range.
	var damage_this_tick: int = max(1, int(ceil(damage_per_second * delta)))
	var my_pos: Vector2 = Vector2(global_position.x, global_position.z)
	var soldier_pos: Vector2 = Vector2(soldier.global_position.x, soldier.global_position.z)
	var best_target: Node3D = soldier
	var best_dist: float = my_pos.distance_to(soldier_pos)

	for clone_node in get_tree().get_nodes_in_group("clones"):
		var clone_obj: Node3D = clone_node as Node3D
		if clone_obj == null:
			continue
		var cpos: Vector2 = Vector2(clone_obj.global_position.x, clone_obj.global_position.z)
		var d: float = my_pos.distance_to(cpos)
		if d < best_dist:
			best_dist = d
			best_target = clone_obj

	if best_dist < _melee_range and best_target != null:
		if best_target.has_method("take_damage"):
			best_target.take_damage(damage_this_tick)


func take_damage(amount: int) -> void:
	if _dead:
		return
	hp -= amount
	_update_boss_hp_bar()
	if hp <= 0:
		_dead = true
		var burst_pos: Vector3 = global_position + Vector3(0, 0.85, 0)
		if max_hp >= BOSS_HP_THRESHOLD:
			Effects.spawn_boss_death(burst_pos)
		else:
			Effects.spawn_zombie_death(burst_pos)
		GameManager.on_zombie_killed()
		GameManager.add_kill_charge()
		queue_free()


func _create_boss_hp_bar() -> void:
	# Floating HP bar above the boss's head. Background is a dark rect;
	# the fill is a red rect whose QuadMesh size.x shrinks from full to
	# zero as hp falls. Both are billboarded + unshaded + depth-test-off
	# so the bar always faces the camera and draws on top of geometry.
	var bar_y: float = 4.6

	var bg: MeshInstance3D = MeshInstance3D.new()
	var bg_mesh: QuadMesh = QuadMesh.new()
	bg_mesh.size = Vector2(_hp_bar_max_width + 0.12, 0.38)
	var bg_mat: StandardMaterial3D = StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0, 0, 0, 0.8)
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.no_depth_test = true
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mesh.material = bg_mat
	bg.mesh = bg_mesh
	bg.position = Vector3(0, bar_y, 0)
	add_child(bg)

	var fill: MeshInstance3D = MeshInstance3D.new()
	_hp_bar_fill_mesh = QuadMesh.new()
	_hp_bar_fill_mesh.size = Vector2(_hp_bar_max_width, 0.3)
	var fill_mat: StandardMaterial3D = StandardMaterial3D.new()
	fill_mat.albedo_color = Color(1, 0.22, 0.22, 1)
	fill_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.no_depth_test = true
	fill_mat.emission_enabled = true
	fill_mat.emission = Color(1, 0.3, 0.3, 1)
	fill_mat.emission_energy_multiplier = 0.8
	_hp_bar_fill_mesh.material = fill_mat
	fill.mesh = _hp_bar_fill_mesh
	fill.position = Vector3(0, bar_y, 0.02)
	add_child(fill)
	_hp_bar_fill = fill


func _update_boss_hp_bar() -> void:
	if _hp_bar_fill == null or _hp_bar_fill_mesh == null:
		return
	var fraction: float = clamp(float(hp) / float(max(max_hp, 1)), 0.0, 1.0)
	var new_width: float = _hp_bar_max_width * fraction
	_hp_bar_fill_mesh.size.x = new_width
	# Anchor to the left edge so the bar drains rightward instead of
	# shrinking from both sides.
	_hp_bar_fill.position.x = -(_hp_bar_max_width - new_width) / 2.0
