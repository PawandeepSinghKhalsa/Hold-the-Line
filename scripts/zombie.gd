extends CharacterBody3D

# Walks forward along +Z toward the soldier. On contact, damages clones.
# Dies when HP <= 0 (hit by bullets).

@export var walk_speed: float = 2.0
@export var max_hp: int = 1
@export var melee_range: float = 0.8

var hp: int
var target: Node3D


func _ready() -> void:
	hp = max_hp
	add_to_group("zombies")


func _physics_process(_delta: float) -> void:
	if target == null:
		return
	var dir := (target.global_position - global_position)
	dir.y = 0
	if dir.length() > 0.01:
		velocity = dir.normalized() * walk_speed
	move_and_slide()

	for shooter in get_tree().get_nodes_in_group("shooters"):
		if global_position.distance_to(shooter.global_position) < melee_range:
			if shooter.has_method("take_melee_hit"):
				shooter.take_melee_hit()
			break


func take_damage(amount: int) -> void:
	hp -= amount
	if hp <= 0:
		queue_free()
