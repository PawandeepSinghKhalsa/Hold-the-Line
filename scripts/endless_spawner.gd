extends Node3D

# Endless mode engine. Continuously pushes waves of zombies + periodic
# gates + periodic mini-bosses ahead of the soldier. Difficulty scales
# with wave_number so each run ends when the leader's HP hits zero.

@export var zombie_scene: PackedScene
@export var gate_scene: PackedScene

@export var wave_interval: float = 8.0
@export var gate_interval: float = 18.0
@export var boss_interval: float = 45.0
@export var spawn_ahead: float = 36.0
@export var gate_ahead: float = 32.0
@export var boss_ahead: float = 40.0

var _wave_timer: float = 4.0
var _gate_timer: float = 14.0
var _boss_timer: float = 40.0
var _soldier: Node3D


func _ready() -> void:
	# Flag endless before any wave logic runs so GameManager.on_zombie_killed
	# doesn't fire a victory when a wave is cleared between spawns.
	GameManager.is_endless = true
	GameManager.wave_number = 0


func _process(delta: float) -> void:
	if _soldier == null:
		_soldier = get_tree().get_first_node_in_group("soldier") as Node3D
		if _soldier == null:
			return
	if not GameManager.is_running:
		return

	_wave_timer -= delta
	if _wave_timer <= 0.0:
		_wave_timer = wave_interval
		_spawn_wave()

	_gate_timer -= delta
	if _gate_timer <= 0.0:
		_gate_timer = gate_interval
		_spawn_gate()

	_boss_timer -= delta
	if _boss_timer <= 0.0:
		_boss_timer = boss_interval
		_spawn_boss()


func _spawn_wave() -> void:
	GameManager.advance_wave()
	var wave: int = GameManager.wave_number
	var per_lane: int = 3 + int(ceil(wave * 0.9))
	var tough_chance: float = clamp(0.04 * wave, 0.0, 0.55)
	var tough_hp: int = 2
	if wave >= 8:
		tough_hp = 3
	var weak_chance: float = clamp(0.5 - wave * 0.02, 0.1, 0.5)

	for lane_idx in GameManager.LANE_COUNT:
		for row in per_lane:
			var zombie: Node3D = zombie_scene.instantiate() as Node3D
			if zombie == null:
				continue
			var is_tough: bool = randf() < tough_chance
			if is_tough:
				zombie.set("max_hp", tough_hp)
			elif randf() < weak_chance:
				zombie.set("is_weak", true)
			zombie.set("lane_index", lane_idx)
			GameManager.add_zombies(1)
			get_tree().current_scene.add_child(zombie)
			var x_jitter: float = randf_range(-0.4, 0.4)
			var z_jitter: float = randf_range(-0.2, 0.2)
			zombie.global_position = Vector3(
				GameManager.LANE_X_POSITIONS[lane_idx] + x_jitter,
				0.1,
				_soldier.global_position.z - spawn_ahead - row * 1.2 + z_jitter
			)


func _spawn_gate() -> void:
	if gate_scene == null:
		return
	var gate: Node3D = gate_scene.instantiate() as Node3D
	if gate == null:
		return
	gate.set("random_combo", true)
	get_tree().current_scene.add_child(gate)
	gate.global_position = Vector3(0, 0.0, _soldier.global_position.z - gate_ahead)


func _spawn_boss() -> void:
	if zombie_scene == null:
		return
	var wave: int = max(GameManager.wave_number, 1)
	var boss_hp: int = 60 + wave * 15
	var boss: Node3D = zombie_scene.instantiate() as Node3D
	if boss == null:
		return
	boss.set("max_hp", boss_hp)
	boss.set("lane_index", 1)
	GameManager.add_zombies(1)
	get_tree().current_scene.add_child(boss)
	boss.global_position = Vector3(0, 0.1, _soldier.global_position.z - boss_ahead)
