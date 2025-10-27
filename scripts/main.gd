extends Node3D

@onready var level: Node3D = $Level
@onready var player: CharacterBody3D = $Player
@onready var stalker: CharacterBody3D = $Stalker
@onready var stamina_bar: ProgressBar = $HUD/Stamina/Bar
@onready var caught_panel: Control = $HUD/CaughtPanel
@onready var caught_label: Label = $HUD/CaughtPanel/Label
@onready var message_label: Label = $HUD/Message
@onready var debug_panel: Control = $HUD/DebugPanel
@onready var debug_label: Label = $HUD/DebugPanel/Label

var _caught := false
var _debug_visible := false
var _debug_refresh := 0.0

func _ready() -> void:
    randomize()
    if not player.is_in_group("player"):
        player.add_to_group("player")
    stalker.call("set_level", level)
    stalker.call("set_player", player)
    player.connect("stamina_changed", Callable(self, "_on_stamina_changed"))
    player.connect("movement_state_changed", Callable(self, "_on_player_movement_state"))
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
    _on_player_movement_state(false, 0.0)

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("toggle_debug_monster"):
        _debug_visible = !_debug_visible
        debug_panel.visible = _debug_visible
        if _debug_visible:
            _update_debug_overlay()
        else:
            debug_label.text = ""

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

func _on_player_movement_state(is_running: bool, intensity: float) -> void:
    if intensity < 0.05:
        message_label.text = "Holding still"
        message_label.self_modulate = Color(0.65, 0.8, 0.7, 0.9)
    elif is_running:
        message_label.text = "Running — it will hear you"
        message_label.self_modulate = Color(0.95, 0.4, 0.35, 0.95)
    else:
        message_label.text = "Walking softly"
        message_label.self_modulate = Color(0.75, 0.75, 0.85, 0.9)

func _process(delta: float) -> void:
    if not _debug_visible:
        return
    _debug_refresh -= delta
    if _debug_refresh <= 0.0:
        _update_debug_overlay()
        _debug_refresh = 0.2

func _update_debug_overlay() -> void:
    if not is_instance_valid(stalker):
        debug_label.text = "Stalker missing"
        return
    if not stalker.has_method("get_debug_info"):
        debug_label.text = "No debug info"
        return
    var info: Dictionary = stalker.call("get_debug_info")
    var lines: Array[String] = []
    lines.append("STATE: %s" % info.get("state", "UNKNOWN"))
    var pos: Vector3 = info.get("position", Vector3.ZERO)
    lines.append("POS: %s" % _format_vector(pos))
    var velocity: Vector3 = info.get("velocity", Vector3.ZERO)
    lines.append("VEL: %s" % _format_vector(velocity))
    var distance: float = info.get("distance_to_player", 0.0)
    lines.append("DIST TO YOU: %.1f m" % distance)
    lines.append("TIME SINCE SEEN: %.1fs" % info.get("time_since_seen", 0.0))
    lines.append("NOISE MEMORY: %.1fs" % info.get("noise_memory", 0.0))
    var target = info.get("current_target", null)
    if typeof(target) == TYPE_VECTOR3:
        lines.append("PATH TARGET: %s" % _format_vector(target))
    else:
        lines.append("PATH TARGET: none")
    lines.append("PATH NODE: %d / %d" % [info.get("path_node", 0), info.get("path_length", 0)])
    var last_noise: Vector3 = info.get("last_noise_position", Vector3.ZERO)
    lines.append("LAST NOISE: %s" % _format_vector(last_noise))
    debug_label.text = "\n".join(lines)

func _format_vector(vec: Vector3) -> String:
    return "(%.1f, %.1f, %.1f)" % [vec.x, vec.y, vec.z]
