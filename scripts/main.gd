extends Node3D

@onready var level: Node3D = $Level
@onready var player: CharacterBody3D = $Player
@onready var stalker: CharacterBody3D = $Stalker
@onready var stamina_bar: ProgressBar = $HUD/Stamina/Bar
@onready var caught_panel: Control = $HUD/CaughtPanel
@onready var caught_label: Label = $HUD/CaughtPanel/Label

var _caught := false

func _ready() -> void:
	randomize()
	if not player.is_in_group("player"):
		player.add_to_group("player")
	stalker.call("set_level", level)
	stalker.call("set_player", player)
	player.connect("stamina_changed", Callable(self, "_on_stamina_changed"))
	stalker.connect("player_caught", Callable(self, "_on_player_caught"))
	stalker.connect("monster_seen", Callable(self, "_on_monster_seen"))
	var player_transform := player.global_transform
	player_transform.origin = level.grid_to_world(Vector2i(3, 1)) + Vector3(0, 1.2, 0)
	player.global_transform = player_transform
	var stalker_transform := stalker.global_transform
	stalker_transform.origin = level.grid_to_world(Vector2i(10, 15)) + Vector3(0, 1.2, 0)
	stalker.global_transform = stalker_transform
	caught_panel.visible = false
	_on_stamina_changed(1.0)

func _on_stamina_changed(value: float) -> void:
	stamina_bar.value = clamp(value * 100.0, 0.0, 100.0)
	stamina_bar.add_theme_color_override("fg_color", Color(0.8, 0.15 + 0.4 * (1.0 - value), 0.1 + 0.4 * (1.0 - value)))

func _on_player_caught() -> void:
	if _caught:
		return
	_caught = true
	caught_panel.visible = true
	caught_label.text = "It heard you."
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true

func _on_monster_seen() -> void:
	player.apply_shake(0.4)
