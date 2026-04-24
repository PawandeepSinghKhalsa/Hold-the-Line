extends Node

# Autoload helper that spawns one-shot CPUParticles3D bursts at world
# positions, "+1" floating-text popups, and a multi-colour victory
# celebration. Also emits a screen_shake_requested signal that the
# camera subscribes to.
#
# Uses CPUParticles3D (not GPU) because the project renders with the
# GL Compatibility backend, which doesn't run GPUParticles3D shaders.

signal screen_shake_requested(intensity: float, duration: float)


func spawn_zombie_death(world_pos: Vector3) -> void:
	_spawn_burst(
		world_pos,
		Color(0.95, 0.2, 0.25),
		25,
		0.6,
		90.0,
		3.5,
		6.5,
		0.13
	)
	spawn_kill_popup(world_pos, "+1", Color(1, 1, 0.4, 1))


func spawn_boss_death(world_pos: Vector3) -> void:
	# Multi-coloured confetti so boss kills feel like a finale.
	var colors: Array[Color] = [
		Color(0.95, 0.25, 0.75),
		Color(0.55, 0.15, 0.9),
		Color(1.0, 0.45, 0.3),
		Color(0.95, 0.85, 0.2),
	]
	for color in colors:
		_spawn_burst(
			world_pos + Vector3(randf_range(-0.4, 0.4), randf_range(0.0, 0.6), 0.0),
			color,
			30,
			1.2,
			130.0,
			4.5,
			9.0,
			0.18
		)
	spawn_kill_popup(world_pos + Vector3(0, 0.8, 0), "BOSS DOWN!", Color(1, 0.4, 0.9, 1), 96)
	screen_shake_requested.emit(3.5, 0.7)


func spawn_muzzle_flash(world_pos: Vector3) -> void:
	_spawn_burst(
		world_pos,
		Color(1.0, 0.9, 0.35),
		5,
		0.12,
		25.0,
		3.5,
		5.5,
		0.1
	)


func spawn_bullet_impact(world_pos: Vector3) -> void:
	_spawn_burst(
		world_pos,
		Color(1.0, 0.75, 0.25),
		5,
		0.2,
		70.0,
		2.5,
		4.5,
		0.09
	)


func spawn_explosion(world_pos: Vector3, radius: float) -> void:
	var r: float = max(radius, 1.0)
	# Orange fireball ball.
	_spawn_burst(
		world_pos,
		Color(1.0, 0.45, 0.15),
		45,
		0.7,
		180.0,
		r * 2.0,
		r * 3.5,
		0.2
	)
	# Darker smoke puff trails behind the fireball.
	_spawn_burst(
		world_pos,
		Color(0.3, 0.2, 0.15),
		20,
		1.2,
		160.0,
		r * 1.2,
		r * 2.0,
		0.25
	)
	screen_shake_requested.emit(2.4, 0.35)


# Floating score text that drifts up and fades out, classic
# hypercasual-shooter feedback for every kill.
func spawn_kill_popup(world_pos: Vector3, text: String = "+1", color: Color = Color(1, 1, 0.4, 1), font_size: int = 64) -> void:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var label: Label3D = Label3D.new()
	label.text = text
	label.font_size = font_size
	label.outline_size = 12
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.005
	scene.add_child(label)
	label.global_position = world_pos + Vector3(0, 1.0, 0)

	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", label.global_position.y + 1.6, 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.2)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)


# Victory finale: rainbow confetti raining around the soldier plus a
# bigger camera shake.
func spawn_victory_celebration() -> void:
	var soldier: Node3D = get_tree().get_first_node_in_group("soldier") as Node3D
	var origin: Vector3 = Vector3.ZERO
	if soldier != null:
		origin = soldier.global_position + Vector3(0, 4.0, -3.0)

	var colors: Array[Color] = [
		Color(1.0, 0.3, 0.3),
		Color(1.0, 0.85, 0.2),
		Color(0.3, 0.9, 0.5),
		Color(0.3, 0.6, 1.0),
		Color(0.85, 0.4, 1.0),
		Color(1.0, 0.6, 0.3),
	]
	for i in colors.size():
		var offset: Vector3 = Vector3(
			randf_range(-3.0, 3.0),
			randf_range(0.0, 1.5),
			randf_range(-1.5, 1.5)
		)
		_spawn_burst(
			origin + offset,
			colors[i],
			40,
			1.6,
			180.0,
			3.0,
			6.5,
			0.14
		)
	spawn_kill_popup(origin, "VICTORY!", Color(0.4, 1, 0.5, 1), 120)
	screen_shake_requested.emit(2.5, 0.55)


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
	particles.gravity = Vector3(0, -6.0, 0)
	particles.scale_amount_min = 1.0
	particles.scale_amount_max = 1.4
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
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = mat
	particles.mesh = sphere

	scene.add_child(particles)
	particles.global_position = world_pos

	var timer: Timer = Timer.new()
	timer.wait_time = lifetime + 0.3
	timer.one_shot = true
	timer.autostart = false
	particles.add_child(timer)
	timer.timeout.connect(particles.queue_free)
	timer.start()
