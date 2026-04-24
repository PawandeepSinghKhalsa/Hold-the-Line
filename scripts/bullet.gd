extends Area3D

# Travels straight forward (-Z) from the soldier. Despawns on zombie hit
# or after LIFETIME seconds. Lane is implicit from spawn X.

const SPEED := 25.0
const DAMAGE := 1
const LIFETIME := 3.0

var _age: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	global_position.z -= SPEED * delta


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("zombies") and body.has_method("take_damage"):
		body.take_damage(DAMAGE)
		queue_free()
