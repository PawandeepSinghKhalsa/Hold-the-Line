extends CharacterBody3D

# Walks toward the soldier (+Z direction). Stays pinned to its lane X.
# On HP <= 0, calls GameManager.on_zombie_killed. On melee range with the
# soldier, ends the run as a loss.

const WALK_SPEED := 3.0
const MELEE_RANGE := 0.9

@export var max_hp: int = 1
var hp: int
var lane_index: int = 1


func _ready() -> void:
	hp = max_hp
	add_to_group("zombies")


func _physics_process(_delta: float) -> void:
	if not GameManager.is_running:
		velocity = Vector3.ZERO
		return

	velocity.z = WALK_SPEED
	move_and_slide()
	global_position.x = GameManager.LANE_X_POSITIONS[lane_index]

	var soldier := get_tree().get_first_node_in_group("soldier")
	if soldier != null and global_position.distance_to(soldier.global_position) < MELEE_RANGE:
		if soldier.has_method("take_melee_hit"):
			soldier.take_melee_hit()


func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		GameManager.on_zombie_killed()
		queue_free()
