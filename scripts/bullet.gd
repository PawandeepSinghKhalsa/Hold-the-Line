extends Area3D

# Simple projectile. Travels in `direction`, despawns on timeout or hit.

@export var speed: float = 20.0
@export var damage: int = 1
@export var lifetime: float = 2.0

var direction: Vector3 = Vector3.FORWARD
var _age: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	global_position += direction * speed * delta


func _on_body_entered(body: Node3D) -> void:
	_try_hit(body)


func _on_area_entered(area: Area3D) -> void:
	_try_hit(area)


func _try_hit(node: Node) -> void:
	if node.is_in_group("zombies") and node.has_method("take_damage"):
		node.take_damage(damage)
		queue_free()
