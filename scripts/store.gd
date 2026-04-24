extends Control

# Store screen. Spends banked kills (earned across all runs) on
# permanent upgrades: Max HP, Fire Rate, Weapon Duration. Each upgrade
# has a fixed max level and per-level cost curve owned by LevelManager.
# Cards are built dynamically so adding a new upgrade only requires
# extending LevelManager.UPGRADES.

@onready var banked_label: Label = $Margin/VBox/BankedLabel
@onready var back_button: Button = $Margin/VBox/BackButton
@onready var cards_container: VBoxContainer = $Margin/VBox/Cards

var _upgrade_keys: Array = []


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	LevelManager.banked_kills_changed.connect(_on_banked_changed)
	LevelManager.upgrade_purchased.connect(_on_upgrade_purchased)
	_upgrade_keys = LevelManager.UPGRADES.keys()
	_build_cards()
	_update_banked_label()


func _build_cards() -> void:
	for child in cards_container.get_children():
		child.queue_free()
	for key in _upgrade_keys:
		cards_container.add_child(_make_card(key))


func _make_card(key: String) -> Control:
	var upgrade: Dictionary = LevelManager.UPGRADES[key]
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 110)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)

	var info: VBoxContainer = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var title_label: Label = Label.new()
	title_label.text = "%s   %s" % [upgrade.name, _pips(key, upgrade.max_level)]
	title_label.add_theme_font_size_override("font_size", 22)
	info.add_child(title_label)

	var desc_label: Label = Label.new()
	desc_label.text = upgrade.description
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.modulate = Color(0.8, 0.8, 0.85, 1)
	info.add_child(desc_label)

	var buy_button: Button = Button.new()
	buy_button.custom_minimum_size = Vector2(140, 80)
	buy_button.focus_mode = Control.FOCUS_NONE
	buy_button.add_theme_font_size_override("font_size", 20)
	var cost: int = LevelManager.upgrade_next_cost(key)
	if cost < 0:
		buy_button.text = "MAX"
		buy_button.disabled = true
	else:
		buy_button.text = "BUY\n%d kills" % cost
		buy_button.disabled = LevelManager.banked_kills < cost
	buy_button.pressed.connect(_on_buy_pressed.bind(key))
	row.add_child(buy_button)

	return panel


func _pips(key: String, max_level: int) -> String:
	var current: int = LevelManager.upgrade_level(key)
	var filled: String = "●".repeat(current)
	var empty: String = "○".repeat(max_level - current)
	return filled + empty


func _on_buy_pressed(key: String) -> void:
	LevelManager.buy_upgrade(key)


func _on_banked_changed(_kills: int) -> void:
	_update_banked_label()
	_build_cards()


func _on_upgrade_purchased(_key: String, _level: int) -> void:
	_build_cards()


func _update_banked_label() -> void:
	banked_label.text = "Banked Kills: %d" % LevelManager.banked_kills


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")
