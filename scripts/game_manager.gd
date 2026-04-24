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
# Hard cap so a weird multiplier combo can't overflow the viewport.
const SQUAD_CAP := 30

# Supercharge tuning. Each use grants a short-lived fire-rate boost to
# every shooter; two uses per run so it remains tactical alongside gate
# multipliers rather than replacing them.
const SUPERCHARGE_MAX := 100.0
const KILL_CHARGE_AMOUNT := 10.0
const SUPERCHARGE_USES_PER_RUN := 2
const SUPERCHARGE_BOOST_DURATION := 4.0
const SUPERCHARGE_FIRE_MULTIPLIER := 2.0

var is_running: bool = false
var zombies_total: int = 0
var zombies_remaining: int = 0
var squad_size: int = 1
var supercharge: float = 0.0
var supercharge_uses_remaining: int = SUPERCHARGE_USES_PER_RUN
var _boost_time_left: float = 0.0


func _process(delta: float) -> void:
	if _boost_time_left <= 0.0:
		return
	_boost_time_left = max(0.0, _boost_time_left - delta)
	supercharge_boost_changed.emit(_boost_time_left > 0.0, _boost_time_left)


func reset() -> void:
	is_running = true
	zombies_total = 0
	zombies_remaining = 0
	squad_size = 1
	supercharge = 0.0
	supercharge_uses_remaining = SUPERCHARGE_USES_PER_RUN
	_boost_time_left = 0.0
	zombies_remaining_changed.emit(zombies_remaining)
	squad_changed.emit(squad_size)
	supercharge_changed.emit(supercharge)
	supercharge_uses_changed.emit(supercharge_uses_remaining)
	supercharge_boost_changed.emit(false, 0.0)


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
	zombies_remaining = max(0, zombies_remaining - 1)
	zombies_remaining_changed.emit(zombies_remaining)
	if zombies_remaining == 0:
		end_run(true)


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
