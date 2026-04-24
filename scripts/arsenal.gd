extends Control

# Arsenal screen. One card per weapon showing the weapon name, current
# tier pips, active-tier stat summary, and an UPGRADE button that spends
# banked kills. Cards are built from GameManager.WEAPON_TIERS so adding
# another weapon in the catalog auto-generates a card here.

@onready var banked_label: Label = $Margin/VBox/BankedLabel
@onready var back_button: Button = $Margin/VBox/BackButton
@onready var cards_container: VBoxContainer = $Margin/VBox/CardsScroll/Cards

const CARD_BG_COLOR := Color(0.13, 0.11, 0.17, 1.0)
const CARD_COLORS: Dictionary = {
	0: Color(0.7, 0.7, 0.75),    # WEAPON_DEFAULT (pistol)
	1: Color(1.0, 0.55, 0.2),    # WEAPON_SHOTGUN
	2: Color(0.3, 0.65, 1.0),    # WEAPON_MACHINE_GUN
	3: Color(0.35, 0.95, 0.5),   # WEAPON_SNIPER
	4: Color(0.95, 0.2, 0.25),   # WEAPON_ROCKET
	5: Color(0.35, 0.8, 1.0),    # WEAPON_LIGHTNING
	6: Color(1.0, 0.4, 0.1),     # WEAPON_FLAME
	7: Color(0.9, 0.9, 0.95),    # WEAPON_RAILGUN
}
const WEAPON_DISPLAY_ORDER: Array = [0, 1, 2, 3, 4, 5, 6, 7]


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	LevelManager.banked_kills_changed.connect(_on_banked_changed)
	LevelManager.weapon_tier_changed.connect(_on_tier_changed)
	LevelManager.weapon_unlocked.connect(_on_weapon_unlocked)
	LevelManager.selected_weapon_changed.connect(_on_selected_changed)
	_rebuild()


func _rebuild() -> void:
	banked_label.text = "%d kills banked" % LevelManager.banked_kills
	for child in cards_container.get_children():
		child.queue_free()
	for weapon_id in WEAPON_DISPLAY_ORDER:
		if not GameManager.WEAPON_TIERS.has(weapon_id):
			continue
		cards_container.add_child(_make_card(int(weapon_id)))


func _make_card(weapon_id: int) -> Control:
	var tint: Color = CARD_COLORS.get(weapon_id, Color(1, 1, 1))
	var tiers: Array = GameManager.WEAPON_TIERS[weapon_id]
	var max_tier_index: int = tiers.size() - 1
	var current_tier: int = LevelManager.get_weapon_tier(weapon_id)
	var is_locked: bool = not LevelManager.is_weapon_unlocked(weapon_id)
	var is_equipped: bool = LevelManager.selected_weapon == weapon_id

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 200)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = CARD_BG_COLOR if not is_locked else Color(0.1, 0.09, 0.12, 1)
	style.border_width_left = 12
	style.border_color = tint if not is_locked else Color(0.35, 0.32, 0.38, 1)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 22
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	card.add_theme_stylebox_override("panel", style)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	# Top row: name + tier/lock label
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	vbox.add_child(top)

	var name_label: Label = Label.new()
	name_label.text = GameManager.WEAPON_NAMES.get(weapon_id, "?")
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1) if not is_locked else Color(0.6, 0.6, 0.65, 1))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)

	var right_label: Label = Label.new()
	if is_locked:
		right_label.text = "LOCKED"
		right_label.add_theme_color_override("font_color", Color(0.7, 0.55, 0.55, 1))
	elif is_equipped:
		right_label.text = "EQUIPPED"
		right_label.add_theme_color_override("font_color", Color(0.5, 1, 0.6))
	else:
		right_label.text = "Tier %d / %d" % [current_tier + 1, max_tier_index + 1]
		right_label.add_theme_color_override("font_color", tint)
	right_label.add_theme_font_size_override("font_size", 22)
	top.add_child(right_label)

	# Pips row
	if not is_locked:
		vbox.add_child(_make_pips_node(current_tier, max_tier_index + 1, tint))

	# Stat summary
	var stat_label: Label = Label.new()
	stat_label.text = _stat_summary(weapon_id, current_tier) if not is_locked else _lock_summary(weapon_id)
	stat_label.add_theme_font_size_override("font_size", 18)
	stat_label.modulate = Color(0.85, 0.85, 0.9, 1) if not is_locked else Color(0.7, 0.65, 0.72, 1)
	vbox.add_child(stat_label)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Bottom row: cost + action button (UNLOCK / UPGRADE / MAXED)
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	vbox.add_child(bottom)

	var cost_label: Label = Label.new()
	cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 24)
	bottom.add_child(cost_label)

	var action_button: Button = Button.new()
	action_button.custom_minimum_size = Vector2(200, 68)
	action_button.focus_mode = Control.FOCUS_NONE
	action_button.add_theme_font_size_override("font_size", 24)
	bottom.add_child(action_button)

	# Upgrade / unlock button on the right, EQUIP button stacked below
	# when the weapon is unlocked and not already equipped.
	if is_locked:
		var unlock_cost: int = LevelManager.weapon_unlock_cost(weapon_id)
		cost_label.text = "Unlock: %d kills" % unlock_cost
		var can_afford: bool = LevelManager.banked_kills >= unlock_cost
		cost_label.add_theme_color_override("font_color", Color(1, 0.95, 0.4) if can_afford else Color(0.9, 0.55, 0.55))
		action_button.text = "UNLOCK"
		action_button.disabled = not can_afford
		_apply_button_style(action_button, tint, can_afford)
		action_button.pressed.connect(_on_unlock_pressed.bind(weapon_id))
	else:
		var cost: int = LevelManager.weapon_next_upgrade_cost(weapon_id)
		if cost < 0:
			cost_label.text = "MAX TIER"
			cost_label.add_theme_color_override("font_color", Color(0.5, 1, 0.6))
			action_button.text = "MAXED"
			action_button.disabled = true
		else:
			cost_label.text = "Upgrade: %d kills" % cost
			var can_afford: bool = LevelManager.banked_kills >= cost
			cost_label.add_theme_color_override("font_color", Color(1, 0.95, 0.4) if can_afford else Color(0.9, 0.55, 0.55))
			action_button.text = "UPGRADE"
			action_button.disabled = not can_afford
			_apply_button_style(action_button, tint, can_afford)
		action_button.pressed.connect(_on_upgrade_pressed.bind(weapon_id))

	# EQUIP row — only shown when the weapon is owned.
	if not is_locked:
		var equip_row: HBoxContainer = HBoxContainer.new()
		equip_row.add_theme_constant_override("separation", 16)
		vbox.add_child(equip_row)
		var equip_spacer: Control = Control.new()
		equip_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		equip_row.add_child(equip_spacer)
		var equip_button: Button = Button.new()
		equip_button.custom_minimum_size = Vector2(200, 52)
		equip_button.focus_mode = Control.FOCUS_NONE
		equip_button.add_theme_font_size_override("font_size", 20)
		if is_equipped:
			equip_button.text = "EQUIPPED"
			equip_button.disabled = true
			var eq_style: StyleBoxFlat = StyleBoxFlat.new()
			eq_style.bg_color = Color(0.25, 0.55, 0.3, 1)
			eq_style.corner_radius_top_left = 10
			eq_style.corner_radius_top_right = 10
			eq_style.corner_radius_bottom_left = 10
			eq_style.corner_radius_bottom_right = 10
			equip_button.add_theme_stylebox_override("disabled", eq_style)
			equip_button.add_theme_color_override("font_color_disabled", Color(1, 1, 1, 1))
		else:
			equip_button.text = "EQUIP"
			_apply_button_style(equip_button, Color(0.45, 0.75, 0.5), true)
			equip_button.pressed.connect(_on_equip_pressed.bind(weapon_id))
		equip_row.add_child(equip_button)
	return card


func _apply_button_style(button: Button, tint: Color, enabled: bool) -> void:
	var base: StyleBoxFlat = StyleBoxFlat.new()
	base.bg_color = tint if enabled else Color(0.3, 0.3, 0.35)
	base.corner_radius_top_left = 10
	base.corner_radius_top_right = 10
	base.corner_radius_bottom_left = 10
	base.corner_radius_bottom_right = 10
	button.add_theme_stylebox_override("normal", base)
	var hover: StyleBoxFlat = base.duplicate() as StyleBoxFlat
	hover.bg_color = tint.lightened(0.12)
	button.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = base.duplicate() as StyleBoxFlat
	pressed.bg_color = tint.darkened(0.15)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0, 0, 0))


func _make_pips_node(current_count: int, total: int, tint: Color) -> Control:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	for i in range(total):
		var pip: PanelContainer = PanelContainer.new()
		pip.custom_minimum_size = Vector2(22, 22)
		var style: StyleBoxFlat = StyleBoxFlat.new()
		if i <= current_count:
			style.bg_color = tint
		else:
			style.bg_color = Color(0.22, 0.2, 0.26, 1)
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.border_color = Color(0.5, 0.45, 0.55, 1)
		style.corner_radius_top_left = 11
		style.corner_radius_top_right = 11
		style.corner_radius_bottom_left = 11
		style.corner_radius_bottom_right = 11
		pip.add_theme_stylebox_override("panel", style)
		hbox.add_child(pip)
	return hbox


func _stat_summary(weapon_id: int, tier_index: int) -> String:
	var tiers: Array = GameManager.WEAPON_TIERS[weapon_id]
	var tier: Dictionary = tiers[tier_index]
	match weapon_id:
		GameManager.WEAPON_DEFAULT:
			return "Standard issue — always available"
		GameManager.WEAPON_SHOTGUN:
			return "%d pellets, %d damage each" % [int(tier.get("pellets", 3)), int(tier.get("damage", 1))]
		GameManager.WEAPON_MACHINE_GUN:
			var rate_mult: float = 1.0 / max(float(tier.get("fire_mult", 0.4)), 0.01)
			return "%d damage, %.1fx fire rate" % [int(tier.get("damage", 1)), rate_mult]
		GameManager.WEAPON_SNIPER:
			var life: float = float(tier.get("lifetime_mult", 1.0))
			return "%d damage, pierces all, range %.1fx" % [int(tier.get("damage", 5)), life]
		GameManager.WEAPON_ROCKET:
			return "%d direct / %d AOE, radius %.1f" % [int(tier.get("damage", 4)), int(tier.get("aoe_damage", 4)), float(tier.get("radius", 3.5))]
		GameManager.WEAPON_LIGHTNING:
			return "%d damage, chains %d times within %.1fu" % [int(tier.get("damage", 2)), int(tier.get("chain_count", 2)), float(tier.get("chain_range", 4.0))]
		GameManager.WEAPON_FLAME:
			var fr: float = 1.0 / max(float(tier.get("fire_mult", 0.2)), 0.01)
			return "%d pellets cone, %d damage, %.1fx fire rate" % [int(tier.get("pellets", 7)), int(tier.get("damage", 1)), fr]
		GameManager.WEAPON_RAILGUN:
			return "%d damage, pierces all, %.1fx range" % [int(tier.get("damage", 15)), float(tier.get("lifetime_mult", 2.0))]
	return ""


func _lock_summary(weapon_id: int) -> String:
	match weapon_id:
		GameManager.WEAPON_LIGHTNING:
			return "Chains lightning between nearby zombies"
		GameManager.WEAPON_FLAME:
			return "Wide cone of fire — crowd clearer"
		GameManager.WEAPON_RAILGUN:
			return "Ultimate sniper — 15+ damage, pierces everything"
	return "Locked"


func _on_upgrade_pressed(weapon_id: int) -> void:
	LevelManager.upgrade_weapon(weapon_id)


func _on_unlock_pressed(weapon_id: int) -> void:
	LevelManager.unlock_weapon(weapon_id)


func _on_weapon_unlocked(_id: int) -> void:
	_rebuild()


func _on_equip_pressed(weapon_id: int) -> void:
	LevelManager.set_selected_weapon(weapon_id)


func _on_selected_changed(_id: int) -> void:
	_rebuild()


func _on_banked_changed(_kills: int) -> void:
	_rebuild()


func _on_tier_changed(_id: int, _tier: int) -> void:
	_rebuild()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")
