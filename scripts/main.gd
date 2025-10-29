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
@onready var path_debug: PathVisualizer = $PathDebug
@onready var monster_view: SubViewportContainer = $HUD/MonsterView
@onready var monster_viewport: SubViewport = $HUD/MonsterView/Viewport
@onready var monster_view_camera: Camera3D = $HUD/MonsterView/Viewport/Camera

var _caught := false
var _debug_visible := false
var _debug_refresh := 0.0
var _path_debug_visible := false
var _monster_view_enabled := false
var _monster_cam_position: Vector3 = Vector3.ZERO

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
    if path_debug:
        path_debug.visible = false
    if monster_viewport:
        monster_viewport.world_3d = get_viewport().world_3d
        monster_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
    if monster_view:
        monster_view.visible = false

func _input(event: InputEvent) -> void:
    if event.is_action_pressed("toggle_debug_monster"):
        _debug_visible = !_debug_visible
        debug_panel.visible = _debug_visible
        if _debug_visible:
            _update_debug_overlay()
        else:
            debug_label.text = ""
    elif event.is_action_pressed("toggle_path_debug"):
        _path_debug_visible = !_path_debug_visible
        if not _path_debug_visible and path_debug:
            path_debug.visible = false
            path_debug.clear()
    elif event.is_action_pressed("toggle_monster_view"):
        _set_monster_view_enabled(!_monster_view_enabled)

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
    if _debug_visible:
        _debug_refresh -= delta
        if _debug_refresh <= 0.0:
            _update_debug_overlay()
            _debug_refresh = 0.2
    if _path_debug_visible:
        _update_path_debug()
    if _monster_view_enabled:
        _update_monster_view(delta)

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
    lines.append("ON FLOOR: %s" % ("YES" if info.get("on_floor", false) else "NO"))
    lines.append("STUCK TIMER: %.2fs" % info.get("stuck_time", 0.0))
    lines.append("TIME SINCE SEEN: %.1fs" % info.get("time_since_seen", 0.0))
    lines.append("NOISE MEMORY: %.1fs" % info.get("noise_memory", 0.0))
    var target = info.get("current_target", null)
    if typeof(target) == TYPE_VECTOR3:
        lines.append("PATH TARGET: %s" % _format_vector(target))
    else:
        lines.append("PATH TARGET: none")
    lines.append("PATH NODE: %d / %d" % [info.get("path_node", 0), info.get("path_length", 0)])
    var active_target = info.get("active_target_world", null)
    if typeof(active_target) == TYPE_VECTOR3:
        lines.append("STEERING TOWARD: %s" % _format_vector(active_target))
    var reason: String = str(info.get("last_path_reason", ""))
    if reason.length() > 0:
        lines.append("LAST REPATH: %s" % reason)
    var path_debug: Dictionary = info.get("path_debug", {})
    if path_debug.size() > 0:
        lines.append("REQ CELLS: %s -> %s" % [path_debug.get("requested_start", Vector2i.ZERO), path_debug.get("requested_goal", Vector2i.ZERO)])
        lines.append("ADJ CELLS: %s -> %s" % [path_debug.get("actual_start", Vector2i.ZERO), path_debug.get("actual_goal", Vector2i.ZERO)])
        lines.append("FOUND PATH: %s (%d steps)" % ["YES" if path_debug.get("found", false) else "NO", path_debug.get("path_length", 0)])
        lines.append("START OFFSET: %d, GOAL OFFSET: %d" % [path_debug.get("start_adjust_steps", 0), path_debug.get("goal_adjust_steps", 0)])
        if path_debug.has("used_fallback"):
            var fallback_cell: Vector2i = path_debug.get("fallback_cell", Vector2i.ZERO)
            var fallback_dist: float = path_debug.get("fallback_distance", 0.0)
            var fallback_flag: String = "YES" if path_debug.get("used_fallback", false) else "NO"
            lines.append("FALLBACK: %s @ %s (%.1f cells)" % [fallback_flag, fallback_cell, fallback_dist])
    var last_noise: Vector3 = info.get("last_noise_position", Vector3.ZERO)
    lines.append("LAST NOISE: %s" % _format_vector(last_noise))
    debug_label.text = "\n".join(lines)

func _format_vector(vec: Vector3) -> String:
    return "(%.1f, %.1f, %.1f)" % [vec.x, vec.y, vec.z]

func _update_path_debug() -> void:
    if not path_debug:
        return
    if not is_instance_valid(stalker):
        path_debug.visible = false
        path_debug.clear()
        return
    var points: PackedVector3Array = PackedVector3Array()
    if stalker.has_method("get_path_points"):
        points = stalker.call("get_path_points")
    var height: float = stalker.global_transform.origin.y
    path_debug.visible = true
    path_debug.update_debug(points, height, stalker.global_transform.origin, stalker.velocity)

func _set_monster_view_enabled(enabled: bool) -> void:
    if not monster_view or not monster_viewport or not monster_view_camera:
        _monster_view_enabled = false
        return
    if enabled and not is_instance_valid(stalker):
        _monster_view_enabled = false
        return
    _monster_view_enabled = enabled
    monster_view.visible = _monster_view_enabled
    monster_viewport.render_target_update_mode = (
        SubViewport.UPDATE_ALWAYS if _monster_view_enabled else SubViewport.UPDATE_DISABLED
    )
    if monster_view_camera:
        monster_view_camera.current = _monster_view_enabled
    if _monster_view_enabled:
        _monster_cam_position = stalker.global_transform.origin + Vector3(0, 6.5, 9.0)
        var start_transform: Transform3D = monster_view_camera.global_transform
        start_transform.origin = _monster_cam_position
        monster_view_camera.global_transform = start_transform
        monster_view_camera.look_at(stalker.global_transform.origin + Vector3.UP, Vector3.UP)

func _update_monster_view(delta: float) -> void:
    if not _monster_view_enabled:
        return
    if not is_instance_valid(stalker):
        _set_monster_view_enabled(false)
        return
    var target: Vector3 = stalker.global_transform.origin + Vector3(0, 0.8, 0)
    var desired: Vector3 = target + Vector3(0, 6.5, 9.0)
    var lerp_speed: float = clampf(delta * 6.0, 0.0, 1.0)
    _monster_cam_position = _monster_cam_position.lerp(desired, lerp_speed)
    var current_transform: Transform3D = monster_view_camera.global_transform
    current_transform.origin = _monster_cam_position
    monster_view_camera.global_transform = current_transform
    monster_view_camera.look_at(target, Vector3.UP)
