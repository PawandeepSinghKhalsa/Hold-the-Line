extends Node3D

# Spawns one boss zombie behind the main horde as the level's finale.
# Uses the regular zombie scene with max_hp >= BOSS_HP_THRESHOLD so the
# zombie script auto-applies its boss visuals (wider, taller, purple
# glow) and slower walk speed.

@export var zombie_scene: PackedScene
@export var boss_hp: int = 50
@export var boss_z: float = -140.0
@export var boss_lane: int = 1


func _ready() -> void:
	call_deferred("_spawn_boss")


func _spawn_boss() -> void:
	if zombie_scene == null:
		return
	var boss_node: Node = zombie_scene.instantiate()
	var boss: Node3D = boss_node as Node3D
	if boss == null:
		return
	# Set max_hp before add_child so zombie._ready() picks up boss tier.
	boss.set("max_hp", boss_hp)
	boss.set("lane_index", boss_lane)
	GameManager.add_zombies(1)
	get_tree().current_scene.add_child(boss)
	var lane_x: float = GameManager.LANE_X_POSITIONS[clamp(boss_lane, 0, GameManager.LANE_COUNT - 1)]
	boss.global_position = Vector3(lane_x, 0.1, boss_z)
