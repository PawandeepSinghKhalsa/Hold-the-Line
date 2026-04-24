extends CharacterBody3D

# Auto-walks forward at FORWARD_SPEED. Player holds A/D or arrow keys to
# strafe laterally at STRAFE_SPEED; release stops the sideways motion.
# On mobile, holding a finger on the left or right half of the screen
# presses the same action, so a sustained touch strafes continuously.
#
# Has HP (instead of instant death on zombie contact). Zombies deal
# damage-per-second while in melee range; run ends when HP hits 0.

signal lane_changed(new_lane: int)
signal hp_changed(current: int, maximum: int)

const STRAFE_SPEED := 1.2
const BRIDGE_HALF_WIDTH := 2.1
const FIRE_INTERVAL := 0.33
const BULLET_SPAWN_OFFSET := Vector3(0, 0.9, -0.5)
const BASE_MAX_HP := 100

@export var bullet_scene: PackedScene

var max_hp: int = BASE_MAX_HP
var hp: int = BASE_MAX_HP
var _fire_cooldown: float = 0.0
var _touch_down: bool = false
var _last_reported_lane: int = -1


func _ready() -> void:
	GameManager.reset()
	add_to_group("soldier")
	max_hp = LevelManager.effective_max_hp(BASE_MAX_HP)
	hp = max_hp
	hp_changed.emit(hp, max_hp)
	_emit_lane_for_current_x()


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_running:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down = true
			_update_touch_direction(event.position.x)
		else:
			_touch_down = false
			Input.action_release("move_left")
			Input.action_release("move_right")
	elif event is InputEventScreenDrag and _touch_down:
		_update_touch_direction(event.position.x)


func _update_touch_direction(screen_x: float) -> void:
	var half_width: float = get_viewport().get_visible_rect().size.x / 2.0
	if screen_x < half_width:
		Input.action_release("move_right")
		Input.action_press("move_left")
	else:
		Input.action_release("move_left")
		Input.action_press("move_right")


func _physics_process(delta: float) -> void:
	if not GameManager.is_running:
		velocity = Vector3.ZERO
		return

	var lateral: float = Input.get_axis("move_left", "move_right")
	velocity.x = lateral * STRAFE_SPEED
	velocity.z = -GameManager.FORWARD_SPEED

	move_and_slide()
	position.x = clamp(position.x, -BRIDGE_HALF_WIDTH, BRIDGE_HALF_WIDTH)

	_emit_lane_for_current_x()

	_fire_cooldown -= delta
	if _fire_cooldown <= 0.0:
		_fire_cooldown = GameManager.current_fire_interval(FIRE_INTERVAL)
		_shoot()


func _shoot() -> void:
	if bullet_scene == null:
		return
	var spawn_pos: Vector3 = global_position + BULLET_SPAWN_OFFSET
	_fire_for_active_weapon(spawn_pos)
	Effects.spawn_muzzle_flash(spawn_pos)


func _fire_for_active_weapon(spawn_pos: Vector3) -> void:
	match GameManager.active_weapon:
		GameManager.WEAPON_SHOTGUN:
			_fire_shotgun(spawn_pos)
		GameManager.WEAPON_SNIPER:
			_fire_sniper(spawn_pos)
		GameManager.WEAPON_ROCKET:
			_fire_rocket(spawn_pos)
		GameManager.WEAPON_MACHINE_GUN:
			var dmg: int = int(GameManager.weapon_stat(GameManager.WEAPON_MACHINE_GUN, "damage", 1))
			_spawn_bullet(spawn_pos, Vector3(0.0, 0, -1.0), dmg, false)
		_:
			_spawn_bullet(spawn_pos, Vector3(0.0, 0, -1.0), 1, false)


func _fire_shotgun(spawn_pos: Vector3) -> void:
	var pellets: int = int(GameManager.weapon_stat(GameManager.WEAPON_SHOTGUN, "pellets", 3))
	var damage: int = int(GameManager.weapon_stat(GameManager.WEAPON_SHOTGUN, "damage", 1))
	pellets = max(pellets, 1)
	var spread: float = 0.24
	for i in pellets:
		var t: float = 0.5 if pellets <= 1 else float(i) / float(pellets - 1)
		var x: float = lerp(-spread, spread, t)
		var dir: Vector3 = Vector3(x, 0, -1).normalized()
		_spawn_bullet(spawn_pos, dir, damage, false)


func _fire_sniper(spawn_pos: Vector3) -> void:
	var damage: int = int(GameManager.weapon_stat(GameManager.WEAPON_SNIPER, "damage", 5))
	var lifetime_mult: float = float(GameManager.weapon_stat(GameManager.WEAPON_SNIPER, "lifetime_mult", 1.0))
	_spawn_bullet(spawn_pos, Vector3(0.0, 0, -1.0), damage, true, lifetime_mult)


func _fire_rocket(spawn_pos: Vector3) -> void:
	var bullet: Node3D = bullet_scene.instantiate() as Node3D
	if bullet == null:
		return
	var dmg: int = int(GameManager.weapon_stat(GameManager.WEAPON_ROCKET, "damage", 4))
	var radius: float = float(GameManager.weapon_stat(GameManager.WEAPON_ROCKET, "radius", 3.5))
	var aoe: int = int(GameManager.weapon_stat(GameManager.WEAPON_ROCKET, "aoe_damage", 4))
	bullet.set("direction", Vector3(0.0, 0, -1.0))
	bullet.set("damage_override", dmg)
	bullet.set("pierce_all", false)
	bullet.set("explosion_radius", radius)
	bullet.set("explosion_damage", aoe)
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = spawn_pos


func _spawn_bullet(spawn_pos: Vector3, direction: Vector3, damage: int, pierce_all: bool, lifetime_mult: float = 1.0) -> void:
	var bullet: Node3D = bullet_scene.instantiate() as Node3D
	if bullet == null:
		return
	bullet.set("direction", direction)
	bullet.set("damage_override", damage)
	bullet.set("pierce_all", pierce_all)
	bullet.set("lifetime_multiplier", lifetime_mult)
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = spawn_pos


func _emit_lane_for_current_x() -> void:
	# Map the continuous X to a "closest lane" index (0=left, 1=centre,
	# 2=right) so the HUD can still show a lane indicator.
	var lane: int = 1
	if position.x < -0.75:
		lane = 0
	elif position.x > 0.75:
		lane = 2
	if lane != _last_reported_lane:
		_last_reported_lane = lane
		lane_changed.emit(lane)


func take_melee_hit() -> void:
	# Legacy method name — zombies now call take_damage for DPS, but keep
	# this as an alias so the Phase-2 insta-kill callers still work.
	take_damage(max_hp)


func take_damage(amount: int) -> void:
	if not GameManager.is_running or hp <= 0:
		return
	hp = max(0, hp - amount)
	hp_changed.emit(hp, max_hp)
	if hp <= 0:
		GameManager.end_run(false)
