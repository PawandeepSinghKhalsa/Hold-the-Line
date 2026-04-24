extends Area3D

# Weapon crate pickup. When the soldier enters the trigger area, activates
# the configured weapon on GameManager for WEAPON_PICKUP_DURATION seconds
# and despawns. Label3D above the box names the weapon so the player can
# choose which lane to drift into.

@export var weapon_id: int = 1  # GameManager.WEAPON_SHOTGUN default

var _consumed: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_apply_visuals()


func _on_body_entered(body: Node) -> void:
	if _consumed:
		return
	if body == null or not body.is_in_group("soldier"):
		return
	_consumed = true
	GameManager.activate_weapon(weapon_id)
	Effects.spawn_kill_popup(
		global_position + Vector3(0, 1.2, 0),
		GameManager.WEAPON_NAMES.get(weapon_id, "Weapon"),
		Color(1, 0.95, 0.4, 1),
		72
	)
	queue_free()


func _apply_visuals() -> void:
	var mesh_instance: MeshInstance3D = get_node_or_null("Mesh") as MeshInstance3D
	var label: Label3D = get_node_or_null("Label") as Label3D
	var tint: Color = _color_for_weapon()
	var weapon_name: String = GameManager.WEAPON_NAMES.get(weapon_id, "?")

	if mesh_instance != null and mesh_instance.material_override != null:
		var unique_mat: Material = mesh_instance.material_override.duplicate() as Material
		mesh_instance.material_override = unique_mat
		var sm: StandardMaterial3D = unique_mat as StandardMaterial3D
		if sm != null:
			sm.albedo_color = Color(tint.r, tint.g, tint.b, 0.75)
			sm.emission_enabled = true
			sm.emission = tint
			sm.emission_energy_multiplier = 0.9

	if label != null:
		label.text = weapon_name.to_upper()
		label.modulate = Color(1, 1, 1, 1)


func _color_for_weapon() -> Color:
	match weapon_id:
		GameManager.WEAPON_SHOTGUN:
			return Color(1.0, 0.55, 0.2)
		GameManager.WEAPON_MACHINE_GUN:
			return Color(0.3, 0.65, 1.0)
		GameManager.WEAPON_SNIPER:
			return Color(0.35, 0.95, 0.5)
		GameManager.WEAPON_ROCKET:
			return Color(0.95, 0.2, 0.25)
		GameManager.WEAPON_LIGHTNING:
			return Color(0.35, 0.8, 1.0)
		GameManager.WEAPON_FLAME:
			return Color(1.0, 0.4, 0.1)
		GameManager.WEAPON_RAILGUN:
			return Color(0.9, 0.9, 0.95)
		_:
			return Color(1, 1, 1)
