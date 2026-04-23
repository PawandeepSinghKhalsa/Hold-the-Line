extends Area3D

# End-of-bridge trigger. Marks the run complete when the soldier reaches it.

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("soldier"):
		GameManager.end_run()
