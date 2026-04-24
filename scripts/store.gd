extends Control

# Store screen. Spends banked kills on permanent upgrades. Cards are
# built dynamically so adding a new upgrade only requires extending
# LevelManager.UPGRADES. Visuals are tuned for mobile: large fonts,
# colour-coded left borders per upgrade, high-contrast badges.

@onready var banked_label: Label = $Margin/VBox/BankedLabel
@onready var back_button: Button = $Margin/VBox/BackButton
@onready var cards_container: VBoxContainer = $Margin/VBox/Cards

const CARD_BG_COLOR := Color(0.13, 0.11, 0.17, 1.0)
const CARD_DISABLED_TINT := Color(0.6, 0.6, 0.65, 1.0)
const CARD_COLORS: Dictionary = {
	"hp": Color(1.0, 0.32, 0.35),
	"fire_rate": Color(1.0, 0.65, 0.2),
	"weapon_duration": Color(0.3, 0.75, 1.0),
}
const CARD_ICONS: Dictionary = {
	"hp": "HP",
	"fire_rate": "RATE",
	"weapon_duration": "TIME",
}


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	LevelManager.banked_kills_changed.connect(_on_banked_changed)
	LevelManager.upgrade_purchased.connect(_on_upgrade_purchased)
	_build_cards()
	_update_banked_label()


func _build_cards() -> void:
	for child in cards_container.get_children():
		child.queue_free()
	for key in LevelManager.UPGRADES.keys():
		cards_container.add_child(_make_card(key))


func _make_card(key: String) -> Control:
	var upgrade: Dictionary = LevelManager.UPGRADES[key]
	var tint: Color = CARD_COLORS.get(key, Color(1, 1, 1))

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(480, 180)
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

	# Top row: category badge + upgrade name + pips
	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 14)
	vbox.add_child(top_row)

	var badge: Label = Label.new()
	badge.text = CARD_ICONS.get(key, "★")
	badge.add_theme_font_size_override("font_size", 22)
	badge.add_theme_color_override("font_color", tint)
	badge.custom_minimum_size = Vector2(72, 0)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	top_row.add_child(badge)

	var name_label: Label = Label.new()
	name_label.text = upgrade.name
	name_label.add_theme_font_size_override("font_size", 32)
	name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_label)

	var pips_node: Control = _make_pips_node(key, upgrade.max_level, tint)
	top_row.add_child(pips_node)

	# Description
	var desc_label: Label = Label.new()
	desc_label.text = upgrade.description
	desc_label.add_theme_font_size_override("font_size", 20)
	desc_label.modulate = Color(0.85, 0.85, 0.9, 1)
	vbox.add_child(desc_label)

	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# Bottom row: cost + BUY button
	var bottom_row: HBoxContainer = HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 16)
	vbox.add_child(bottom_row)

	var cost_label: Label = Label.new()
	cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_font_size_override("font_size", 26)
	bottom_row.add_child(cost_label)

	var buy_button: Button = Button.new()
	buy_button.custom_minimum_size = Vector2(180, 68)
	buy_button.focus_mode = Control.FOCUS_NONE
	buy_button.add_theme_font_size_override("font_size", 26)
	bottom_row.add_child(buy_button)

	var cost: int = LevelManager.upgrade_next_cost(key)
	if cost < 0:
		cost_label.text = "MAX LEVEL"
		cost_label.add_theme_color_override("font_color", Color(0.5, 1, 0.6))
		buy_button.text = "MAXED"
		buy_button.disabled = true
	else:
		cost_label.text = "Cost: %d kills" % cost
		var can_afford: bool = LevelManager.banked_kills >= cost
		var cost_color: Color = Color(1, 0.95, 0.4) if can_afford else Color(0.9, 0.55, 0.55)
		cost_label.add_theme_color_override("font_color", cost_color)
		buy_button.text = "BUY"
		buy_button.disabled = not can_afford
		var buy_style: StyleBoxFlat = StyleBoxFlat.new()
		buy_style.bg_color = tint if can_afford else Color(0.3, 0.3, 0.35)
		buy_style.corner_radius_top_left = 10
		buy_style.corner_radius_top_right = 10
		buy_style.corner_radius_bottom_left = 10
		buy_style.corner_radius_bottom_right = 10
		buy_button.add_theme_stylebox_override("normal", buy_style)
		var hover_style: StyleBoxFlat = buy_style.duplicate() as StyleBoxFlat
		hover_style.bg_color = tint.lightened(0.12)
		buy_button.add_theme_stylebox_override("hover", hover_style)
		var pressed_style: StyleBoxFlat = buy_style.duplicate() as StyleBoxFlat
		pressed_style.bg_color = tint.darkened(0.15)
		buy_button.add_theme_stylebox_override("pressed", pressed_style)
		buy_button.add_theme_color_override("font_color", Color(0, 0, 0))

	buy_button.pressed.connect(_on_buy_pressed.bind(key))
	return card


func _make_pips_node(key: String, max_level: int, tint: Color) -> Control:
	# Pips used to be ●/○ Unicode glyphs but Godot's default font doesn't
	# ship those codepoints — they rendered as tofu squares on mobile.
	# Building them as tiny rounded PanelContainers instead so they're
	# guaranteed to draw correctly on every platform.
	var current: int = LevelManager.upgrade_level(key)
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	for i in range(max_level):
		var pip: PanelContainer = PanelContainer.new()
		pip.custom_minimum_size = Vector2(22, 22)
		var style: StyleBoxFlat = StyleBoxFlat.new()
		if i < current:
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


func _on_buy_pressed(key: String) -> void:
	LevelManager.buy_upgrade(key)


func _on_banked_changed(_kills: int) -> void:
	_update_banked_label()
	_build_cards()


func _on_upgrade_purchased(_key: String, _level: int) -> void:
	_build_cards()


func _update_banked_label() -> void:
	banked_label.text = "%d kills banked" % LevelManager.banked_kills


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")
