extends Node

# Autoload singleton. Phase 3-5 state: lane geometry, run state, zombie
# count, squad size + clone formation math for multiplier gates, and the
# supercharge meter used for time-limited fire-rate boosts.

signal run_ended(won: bool)
signal zombies_remaining_changed(remaining: int)
signal squad_changed(new_size: int)
signal supercharge_changed(fill_pct: float)
signal supercharge_uses_changed(uses_left: int)
signal supercharge_boost_changed(is_active: bool, time_left: float)

const FORWARD_SPEED := 2.0
const LANE_X_POSITIONS := [-1.5, 0.0, 1.5]
const LANE_COUNT := 3
const BRIDGE_LENGTH := 100.0

# Clone formation used by gates to place new clones behind the leader.
const CLONES_PER_ROW := 3
const CLONE_ROW_SPACING := 1.0
const CLONE_COL_SPACING := 0.8
# Hard cap: 1 leader + 8 clones = 9 soldiers, fits in 3 rows of 3 behind
# the leader so the formation never overflows the camera frame.
const SQUAD_CAP := 9

# Supercharge tuning. Each use grants a short-lived fire-rate boost to
# every shooter; two uses per run so it remains tactical alongside gate
# multipliers rather than replacing them.
const SUPERCHARGE_MAX := 100.0
const KILL_CHARGE_AMOUNT := 10.0
const SUPERCHARGE_USES_PER_RUN := 2
const SUPERCHARGE_BOOST_DURATION := 4.0
const SUPERCHARGE_FIRE_MULTIPLIER := 2.0

# Weapon pickups — temporary upgrades dropped in crates on the bridge.
const WEAPON_DEFAULT := 0
const WEAPON_SHOTGUN := 1
const WEAPON_MACHINE_GUN := 2
const WEAPON_SNIPER := 3
const WEAPON_ROCKET := 4
const WEAPON_LIGHTNING := 5
const WEAPON_FLAME := 6
const WEAPON_RAILGUN := 7
const WEAPON_PICKUP_DURATION := 8.0
const WEAPON_NAMES: Dictionary = {
	WEAPON_DEFAULT: "Pistol",
	WEAPON_SHOTGUN: "Shotgun",
	WEAPON_MACHINE_GUN: "Machine Gun",
	WEAPON_SNIPER: "Sniper",
	WEAPON_ROCKET: "Rocket",
	WEAPON_LIGHTNING: "Lightning Gun",
	WEAPON_FLAME: "Flamethrower",
	WEAPON_RAILGUN: "Rail Gun",
}
# Locked weapons must be unlocked via the Arsenal before the weapon
# spawner rolls them into crates. Unlock is a one-time cost in banked
# kills; upgrade tiers then work the same way as the default weapons.
const WEAPON_UNLOCK_COSTS: Dictionary = {
	WEAPON_LIGHTNING: 1500,
	WEAPON_FLAME: 2000,
	WEAPON_RAILGUN: 3000,
}

# Per-weapon tier stats. Each weapon has an array of tier dicts indexed
# from 0. Tier 0 is free (the default behaviour); higher tiers are
# bought with banked kills via LevelManager.upgrade_weapon.
#
# Keys vary by weapon:
#   shotgun: pellets, damage
#   machine_gun: damage, fire_mult   (fire_mult multiplies base interval)
#   sniper: damage, lifetime_mult
#   rocket: damage, radius, aoe_damage
# Every entry carries upgrade_cost (0 for the free tier).
const WEAPON_TIERS: Dictionary = {
	WEAPON_SHOTGUN: [
		{"pellets": 3, "damage": 1, "upgrade_cost": 0},
		{"pellets": 4, "damage": 1, "upgrade_cost": 300},
		{"pellets": 5, "damage": 2, "upgrade_cost": 900},
	],
	WEAPON_MACHINE_GUN: [
		{"damage": 1, "fire_mult": 0.40, "upgrade_cost": 0},
		{"damage": 1, "fire_mult": 0.33, "upgrade_cost": 400},
		{"damage": 2, "fire_mult": 0.28, "upgrade_cost": 1000},
	],
	WEAPON_SNIPER: [
		{"damage": 5, "lifetime_mult": 1.0, "upgrade_cost": 0},
		{"damage": 7, "lifetime_mult": 1.0, "upgrade_cost": 500},
		{"damage": 10, "lifetime_mult": 1.5, "upgrade_cost": 1200},
	],
	WEAPON_ROCKET: [
		{"damage": 4, "radius": 3.5, "aoe_damage": 4, "upgrade_cost": 0},
		{"damage": 5, "radius": 4.5, "aoe_damage": 5, "upgrade_cost": 600},
		{"damage": 6, "radius": 5.5, "aoe_damage": 6, "upgrade_cost": 1500},
	],
	WEAPON_LIGHTNING: [
		{"damage": 2, "chain_count": 2, "chain_range": 4.0, "upgrade_cost": 0},
		{"damage": 3, "chain_count": 3, "chain_range": 5.0, "upgrade_cost": 700},
		{"damage": 4, "chain_count": 4, "chain_range": 6.0, "upgrade_cost": 1800},
	],
	WEAPON_FLAME: [
		{"pellets": 7, "damage": 1, "fire_mult": 0.20, "upgrade_cost": 0},
		{"pellets": 9, "damage": 1, "fire_mult": 0.17, "upgrade_cost": 800},
		{"pellets": 11, "damage": 2, "fire_mult": 0.14, "upgrade_cost": 2000},
	],
	WEAPON_RAILGUN: [
		{"damage": 15, "fire_mult": 4.0, "lifetime_mult": 2.0, "upgrade_cost": 0},
		{"damage": 20, "fire_mult": 3.5, "lifetime_mult": 2.5, "upgrade_cost": 1200},
		{"damage": 30, "fire_mult": 3.0, "lifetime_mult": 3.0, "upgrade_cost": 2500},
	],
}

signal weapon_changed(weapon_id: int, time_left: float)
signal wave_advanced(new_wave: int)

var is_running: bool = false
var is_endless: bool = false
var wave_number: int = 0
var zombies_total: int = 0
var zombies_remaining: int = 0
var kills_this_run: int = 0
var squad_size: int = 1
var supercharge: float = 0.0
var supercharge_uses_remaining: int = SUPERCHARGE_USES_PER_RUN
var active_weapon: int = WEAPON_DEFAULT
var _weapon_time_left: float = 0.0
var _boost_time_left: float = 0.0


func _process(delta: float) -> void:
	if _boost_time_left > 0.0:
		_boost_time_left = max(0.0, _boost_time_left - delta)
		supercharge_boost_changed.emit(_boost_time_left > 0.0, _boost_time_left)
	if active_weapon != WEAPON_DEFAULT and _weapon_time_left > 0.0:
		_weapon_time_left = max(0.0, _weapon_time_left - delta)
		if _weapon_time_left <= 0.0:
			active_weapon = WEAPON_DEFAULT
		weapon_changed.emit(active_weapon, _weapon_time_left)


func reset() -> void:
	is_running = true
	is_endless = false
	wave_number = 0
	zombies_total = 0
	zombies_remaining = 0
	kills_this_run = 0
	squad_size = 1
	supercharge = 0.0
	supercharge_uses_remaining = SUPERCHARGE_USES_PER_RUN
	active_weapon = WEAPON_DEFAULT
	_weapon_time_left = 0.0
	_boost_time_left = 0.0
	zombies_remaining_changed.emit(zombies_remaining)
	squad_changed.emit(squad_size)
	supercharge_changed.emit(supercharge)
	supercharge_uses_changed.emit(supercharge_uses_remaining)
	supercharge_boost_changed.emit(false, 0.0)
	weapon_changed.emit(active_weapon, 0.0)


func set_level_zombie_count(n: int) -> void:
	zombies_total = n
	zombies_remaining = n
	zombies_remaining_changed.emit(zombies_remaining)


func add_zombies(n: int) -> void:
	zombies_total += n
	zombies_remaining += n
	zombies_remaining_changed.emit(zombies_remaining)


func on_zombie_killed() -> void:
	if not is_running:
		return
	kills_this_run += 1
	zombies_remaining = max(0, zombies_remaining - 1)
	zombies_remaining_changed.emit(zombies_remaining)
	# Endless mode only ends when the leader dies — running out of
	# zombies mid-wave just means the next wave is coming.
	if not is_endless and zombies_remaining == 0:
		end_run(true)


func advance_wave() -> void:
	wave_number += 1
	wave_advanced.emit(wave_number)


# Called by clones when a zombie kills them. Drops squad size but keeps
# the run alive until the leader himself dies.
func on_clone_died() -> void:
	if not is_running:
		return
	squad_size = max(1, squad_size - 1)
	squad_changed.emit(squad_size)


func apply_multiplier(multiplier: int) -> int:
	var before: int = squad_size
	squad_size = clamp(squad_size * multiplier, 1, SQUAD_CAP)
	squad_changed.emit(squad_size)
	return squad_size - before


func apply_add(amount: int) -> int:
	var before: int = squad_size
	squad_size = clamp(squad_size + amount, 1, SQUAD_CAP)
	squad_changed.emit(squad_size)
	return squad_size - before


func apply_sub(amount: int) -> int:
	var before: int = squad_size
	squad_size = clamp(squad_size - amount, 1, SQUAD_CAP)
	squad_changed.emit(squad_size)
	return squad_size - before


func apply_div(divisor: int) -> int:
	var before: int = squad_size
	if divisor <= 1:
		return 0
	squad_size = clamp(int(squad_size / divisor), 1, SQUAD_CAP)
	squad_changed.emit(squad_size)
	return squad_size - before


func add_kill_charge(amount: float = KILL_CHARGE_AMOUNT) -> void:
	if not is_running:
		return
	# Stop filling once the player has spent all their allotted uses so the
	# bar visibly "locks" and doesn't tease a tap that can never fire.
	if supercharge_uses_remaining <= 0:
		return
	supercharge = min(SUPERCHARGE_MAX, supercharge + amount)
	supercharge_changed.emit(supercharge)


# Consume a full supercharge bar for a fire-rate boost. Returns true iff
# the bar was full and uses remained.
func try_trigger_supercharge() -> bool:
	if not is_running:
		return false
	if supercharge < SUPERCHARGE_MAX:
		return false
	if supercharge_uses_remaining <= 0:
		return false
	supercharge = 0.0
	supercharge_uses_remaining -= 1
	_boost_time_left = SUPERCHARGE_BOOST_DURATION
	supercharge_changed.emit(supercharge)
	supercharge_uses_changed.emit(supercharge_uses_remaining)
	supercharge_boost_changed.emit(true, _boost_time_left)
	return true


func is_boost_active() -> bool:
	return _boost_time_left > 0.0


func fire_rate_multiplier() -> float:
	return SUPERCHARGE_FIRE_MULTIPLIER if is_boost_active() else 1.0


# Pick up a weapon crate. Temporarily replaces the default pistol with
# the given weapon for WEAPON_PICKUP_DURATION seconds. Re-picking the
# same weapon just refreshes the timer.
func activate_weapon(weapon_id: int) -> void:
	if not is_running:
		return
	if weapon_id == WEAPON_DEFAULT:
		return
	active_weapon = weapon_id
	_weapon_time_left = LevelManager.effective_weapon_duration(WEAPON_PICKUP_DURATION)
	weapon_changed.emit(active_weapon, _weapon_time_left)


func weapon_time_left() -> float:
	return _weapon_time_left


# Per-weapon fire interval, already scaled by the supercharge multiplier.
func current_fire_interval(base_interval: float) -> float:
	var interval: float = base_interval
	match active_weapon:
		WEAPON_MACHINE_GUN, WEAPON_FLAME, WEAPON_RAILGUN:
			interval = base_interval * float(weapon_stat(active_weapon, "fire_mult", 1.0))
		WEAPON_SNIPER:
			interval = base_interval * 2.2  # slow but devastating
		WEAPON_ROCKET:
			interval = base_interval * 3.0  # slowest, but blasts a crowd
		_:
			interval = base_interval
	var total_mult: float = fire_rate_multiplier() * LevelManager.effective_fire_rate_multiplier()
	return interval / total_mult


# Read a single stat for the given weapon using the player's current
# tier from LevelManager. Falls back to `default_value` if the weapon
# has no catalog entry or the key is missing.
func weapon_stat(weapon_id: int, key: String, default_value) -> Variant:
	var tiers: Array = WEAPON_TIERS.get(weapon_id, [])
	if tiers.is_empty():
		return default_value
	var tier_index: int = LevelManager.get_weapon_tier(weapon_id)
	tier_index = clamp(tier_index, 0, tiers.size() - 1)
	return tiers[tier_index].get(key, default_value)


func end_run(won: bool) -> void:
	if not is_running:
		return
	is_running = false
	run_ended.emit(won)


# Compute the local offset (relative to the leader) of the Nth clone in
# the squad. Clones are arranged in rows of CLONES_PER_ROW behind the
# leader, centred horizontally, each row further back along +Z.
func clone_offset_for_index(clone_index: int) -> Vector3:
	var row: int = clone_index / CLONES_PER_ROW
	var col: int = clone_index % CLONES_PER_ROW
	var x: float = (col - (CLONES_PER_ROW - 1) / 2.0) * CLONE_COL_SPACING
	var z: float = (row + 1) * CLONE_ROW_SPACING
	return Vector3(x, 0.0, z)
