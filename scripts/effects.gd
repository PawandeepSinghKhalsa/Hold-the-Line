extends Node

# Autoload helper that spawns one-shot CPUParticles3D bursts at world
# positions and emits a screen-shake request signal that the camera
# subscribes to. Uses CPUParticles3D (not GPU) because the project
# renders with the GL Compatibility backend, which doesn't run
# GPUParticles shaders.

signal screen_shake_requested(intensity: float, duration: float)


func spawn_zombie_death(world_pos: Vector3) -> void:
	_spawn_burst(
		world_pos,
		Color(0.85, 0.15, 0.18),
		10,
		0.35,
		70.0,
		2.5,
		4.5,
		0.07
	)


func spawn_boss_death(world_pos: Vector3) -> void:
	_spawn_burst(
		world_pos,
		Color(0.65, 0.2, 0.75),
		40,
		0.9,
		110.0,
		3.5,
		7.0,
		0.13
	)
	screen_shake_requested.emit(1.6, 0.45)


func spawn_muzzle_flash(world_pos: Vector3) -> void:
	_spawn_burst(
		world_pos,
		Color(1.0, 0.85, 0.3),
		3,
		0.06,
		25.0,
		3.5,
		5.0,
		0.06
	)


func spawn_bullet_impact(world_pos: Vector3) -> void:
	_spawn_burst(
		world_pos,
		Color(1.0, 0.75, 0.25),
		3,
		0.12,
		60.0,
		2.0,
		4.0,
		0.06
	)


func _spawn_burst(
	world_pos: Vector3,
	color: Color,
	amount: int,
	lifetime: float,
	spread_deg: float,
	vmin: float,
	vmax: float,
	particle_radius: float
) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return

	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.emitting = true
	particles.explosiveness = 1.0
	particles.direction = Vector3(0, 1, 0)
	particles.spread = spread_deg
	particles.initial_velocity_min = vmin
	particles.initial_velocity_max = vmax
	particles.gravity = Vector3(0, -4.0, 0)
	particles.color = color

	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = particle_radius
	sphere.height = particle_radius * 2.0
	sphere.radial_segments = 6
	sphere.rings = 3
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.6
	sphere.material = mat
	particles.mesh = sphere

	scene.add_child(particles)
	particles.global_position = world_pos

	# Self-destruct shortly after the longest particle lifetime so the
	# scene tree doesn't accumulate dead emitters.
	var timer: Timer = Timer.new()
	timer.wait_time = lifetime + 0.25
	timer.one_shot = true
	timer.autostart = false
	particles.add_child(timer)
	timer.timeout.connect(particles.queue_free)
	timer.start()
