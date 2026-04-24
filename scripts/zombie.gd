extends CharacterBody3D

# Actively chases the soldier. No longer pinned to a lane — each frame the
# zombie steers toward the soldier's current position, so strafing to a
# new lane no longer guarantees safety. Front zombies block the ones
# behind them (CharacterBody3D collision), so the horde naturally forms
# a mass instead of stacking on a single point.

const WALK_SPEED := 3.0
const MELEE_RANGE := 0.9

@export var max_hp: int = 1
var hp: int
var lane_index: int = 1  # Used by the spawner for initial placement only.


func _ready() -> void:
	hp = max_hp
	add_to_group("zombies")


func _physics_process(_delta: float) -> void:
	if not GameManager.is_running:
		velocity = Vector3.ZERO
		return

	var soldier := get_tree().get_first_node_in_group("soldier")
	if soldier == null:
		velocity = Vector3(0, 0, WALK_SPEED)
	else:
		var to_soldier := soldier.global_position - global_position
		to_soldier.y = 0
		if to_soldier.length() > 0.01:
			velocity = to_soldier.normalized() * WALK_SPEED
		else:
			velocity = Vector3.ZERO

	move_and_slide()

	if soldier != null and global_position.distance_to(soldier.global_position) < MELEE_RANGE:
		if soldier.has_method("take_melee_hit"):
			soldier.take_melee_hit()


func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		GameManager.on_zombie_killed()
		queue_free()
