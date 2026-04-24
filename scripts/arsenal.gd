extends Control

# Arsenal screen. One card per weapon showing the weapon name, current
# tier pips, active-tier stat summary, and an UPGRADE button that spends
# banked kills. Cards are built from GameManager.WEAPON_TIERS so adding
# another weapon in the catalog auto-generates a card here.

@onready var banked_label: Label = $Margin/VBox/BankedLabel
@onready var back_button: Button = $Margin/VBox/BackButton
@onready var cards_container: VBoxContainer = $Margin/VBox/Cards

const CARD_BG_COLOR := Color(0.13, 0.11, 0.17, 1.0)
const CARD_COLORS: Dictionary = {
	1: Color(1.0, 0.55, 0.2),    # WEAPON_SHOTGUN
	2: Color(0.3, 0.65, 1.0),    # WEAPON_MACHINE_GUN
	3: Color(0.35, 0.95, 0.5),   # WEAPON_SNIPER
	4: Color(0.95, 0.2, 0.25),   # WEAPON_ROCKET
}
const WEAPON_DISPLAY_ORDER: Array = [1, 2, 3, 4]


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	LevelManager.banked_kills_changed.connect(_on_banked_changed)
	LevelManager.weapon_tier_changed.connect(_on_tier_changed)
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

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(520, 200)
	card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = CARD_BG_COLOR
	style.border_width_left = 12
	style.border_color = tint
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

	# Top row: name + tier label + pips
	var top: HBoxContainer = HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	vbox.add_child(top)

	var name_label: Label = Label.new()
	name_label.text = GameManager.WEAPON_NAMES.get(weapon_id, "?")
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_label)

	var tier_label: Label = Label.new()
	tier_label.text = "Tier %d / %d" % [current_tier + 1, max_tier_index + 1]
	tier_label.add_theme_font_size_override("font_size", 22)
	tier_label.add_theme_color_override("font_color", tint)
	top.add_child(tier_label)

	# Pips row (built from coloured circles, not Unicode)
	vbox.add_child(_make_pips_node(current_tier, max_tier_index + 1, tint))

	# Stat summary for current tier
	var stat_label: Label = Label.new()
	stat_label.text = _stat_summary(weapon_id, current_tier)
	stat_label.add_theme_font_size_override("font_size", 18)
	stat_label.modulate = Color(0.85, 0.85, 0.9, 1)
	vbox.add_child(stat_label)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Bottom row: next-tier cost + UPGRADE button
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	vbox.add_child(bottom)

	var cost_label: Label = Label.new()
	cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 24)
	bottom.add_child(cost_label)

	var buy_button: Button = Button.new()
	buy_button.custom_minimum_size = Vector2(200, 68)
	buy_button.focus_mode = Control.FOCUS_NONE
	buy_button.add_theme_font_size_override("font_size", 24)
	bottom.add_child(buy_button)

	var cost: int = LevelManager.weapon_next_upgrade_cost(weapon_id)
	if cost < 0:
		cost_label.text = "MAX TIER"
		cost_label.add_theme_color_override("font_color", Color(0.5, 1, 0.6))
		buy_button.text = "MAXED"
		buy_button.disabled = true
	else:
		cost_label.text = "Upgrade: %d kills" % cost
		var can_afford: bool = LevelManager.banked_kills >= cost
		var cost_color: Color = Color(1, 0.95, 0.4) if can_afford else Color(0.9, 0.55, 0.55)
		cost_label.add_theme_color_override("font_color", cost_color)
		buy_button.text = "UPGRADE"
		buy_button.disabled = not can_afford
		_apply_button_style(buy_button, tint, can_afford)

	buy_button.pressed.connect(_on_upgrade_pressed.bind(weapon_id))
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
	return ""


func _on_upgrade_pressed(weapon_id: int) -> void:
	LevelManager.upgrade_weapon(weapon_id)


func _on_banked_changed(_kills: int) -> void:
	_rebuild()


func _on_tier_changed(_id: int, _tier: int) -> void:
	_rebuild()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")
