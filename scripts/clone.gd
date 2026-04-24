extends CharacterBody3D

# A squad clone. Follows the leader at a fixed local offset and auto-fires
# straight ahead at the same cadence as the leader. Clones do not take
# damage from zombies — only the leader's melee contact ends the run.

const FIRE_INTERVAL := 0.33
const BULLET_SPAWN_OFFSET := Vector3(0, 0.9, -0.3)
const FOLLOW_LERP_SPEED := 12.0

@export var bullet_scene: PackedScene

var leader: Node3D
var follow_offset: Vector3 = Vector3.ZERO
var _fire_cooldown: float = 0.0


func _ready() -> void:
	add_to_group("clones")


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
		_fire_cooldown = FIRE_INTERVAL / GameManager.fire_rate_multiplier()
		_shoot()


func _shoot() -> void:
	if bullet_scene == null:
		return
	var bullet: Node3D = bullet_scene.instantiate() as Node3D
	if bullet == null:
		return
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position + BULLET_SPAWN_OFFSET
	Effects.spawn_muzzle_flash(bullet.global_position)
