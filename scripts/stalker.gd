extends CharacterBody3D

signal player_caught
signal monster_seen

@export var move_speed: float = 3.2
@export var lunge_speed: float = 14.0
@export var stalk_speed: float = 2.2
@export var acceleration: float = 6.0
@export var gravity: float = 20.0
@export var attack_distance: float = 1.5
@export var lunge_time: float = 0.4
@export var leash_distance: float = 80.0
@export var patience_time: float = 5.0
@export var hide_distance: float = 14.0
@export var noise_memory_time: float = 7.5
@export var sense_radius: float = 50.0

var _level: Node = null
var _player: CharacterBody3D = null
var _state: String = "STALK"
var _path: PackedVector3Array = PackedVector3Array()
var _path_index: int = 0
var _noise_timer: float = 0.0
var _last_noise_position: Vector3 = Vector3.ZERO
var _time_since_seen: float = 0.0
var _lunge_timer: float = 0.0
var _last_path_debug: Dictionary = {}
var _last_repath_reason: String = ""
var _current_target: Vector3 = Vector3.ZERO
var _stuck_timer: float = 0.0
var _has_current_target: bool = false
var _chase_repath_cooldown: float = 0.0

const _STUCK_SPEED_THRESHOLD: float = 0.25
const _STUCK_TIME_THRESHOLD: float = 1.5

@onready var _body_controller: StalkerBody = get_node_or_null("Body") as StalkerBody

func get_debug_info() -> Dictionary:
    var info := {
        "state": _state,
        "position": global_transform.origin,
        "velocity": Vector3(velocity.x, 0.0, velocity.z),
        "distance_to_player": 0.0,
        "path_node": _path_index,
        "path_length": _path.size(),
        "noise_memory": _noise_timer,
        "time_since_seen": _time_since_seen,
        "last_noise_position": _last_noise_position,
        "on_floor": is_on_floor(),
        "stuck_time": _stuck_timer,
        "last_path_reason": _last_repath_reason,
        "path_debug": _last_path_debug.duplicate(true)
    }
    if _player:
        info["distance_to_player"] = global_transform.origin.distance_to(_player.global_transform.origin)
    if _path_index >= 0 and _path_index < _path.size():
        info["current_target"] = _path[_path_index]
    else:
        info["current_target"] = null
    info["active_target_world"] = _current_target if _has_current_target else null
    return info

func _ready() -> void:
    _level = get_parent().get_node_or_null("Level")
    _player = get_tree().get_first_node_in_group("player") as CharacterBody3D
    if not _player:
        var players: Array[Node] = get_tree().get_nodes_in_group("player")
        if players.size() > 0:
            _player = players[0] as CharacterBody3D
    if _player:
        _player.connect("noise_emitted", Callable(self, "_on_player_noise"))
    randomize()

func set_level(level: Node) -> void:
    _level = level

func set_player(player: CharacterBody3D) -> void:
    _player = player
    if _player and not _player.is_connected("noise_emitted", Callable(self, "_on_player_noise")):
        _player.connect("noise_emitted", Callable(self, "_on_player_noise"))

func _physics_process(delta: float) -> void:
    if not _level or not _player:
        return
    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = 0.0
    if _chase_repath_cooldown > 0.0:
        _chase_repath_cooldown = max(_chase_repath_cooldown - delta, 0.0)

    match _state:
        "STALK":
            _update_stalk(delta)
        "CHASE":
            _update_chase(delta)
        "ATTACK":
            _update_attack(delta)

    move_and_slide()

    if _body_controller:
        var planar_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
        _body_controller.update_motion(planar_velocity, delta, is_on_floor())

    if _state != "ATTACK":
        var horizontal_speed: float = Vector3(velocity.x, 0.0, velocity.z).length()
        if horizontal_speed < _STUCK_SPEED_THRESHOLD and not _path.is_empty():
            _stuck_timer += delta
            if _stuck_timer >= _STUCK_TIME_THRESHOLD:
                _handle_stuck()
        else:
            _stuck_timer = 0.0

func _update_stalk(delta: float) -> void:
    _time_since_seen += delta
    var monster_pos: Vector3 = global_transform.origin
    var player_pos: Vector3 = _player.global_transform.origin
    var distance: float = monster_pos.distance_to(player_pos)

    if distance < sense_radius and (_player_is_visible() or distance < hide_distance * 0.5):
        _enter_chase()
        return

    if distance > leash_distance:
        _teleport_closer()
        return

    if _path.is_empty() or _path_index >= _path.size():
        _choose_hiding_destination(player_pos)
    _follow_path(delta, stalk_speed)

    if distance < hide_distance and _player_is_visible():
        emit_signal("monster_seen")

func _update_chase(delta: float) -> void:
    _time_since_seen += delta
    var monster_pos: Vector3 = global_transform.origin
    var player_pos: Vector3 = _player.global_transform.origin
    var distance: float = monster_pos.distance_to(player_pos)
    var player_visible: bool = _player_is_visible()

    if player_visible:
        _time_since_seen = 0.0
        if distance <= attack_distance * 1.2:
            _enter_attack()
            return
    elif _time_since_seen > patience_time:
        _state = "STALK"
        return

    var need_repath: bool = _path.is_empty()
    if not need_repath:
        if player_visible and _path.size() <= 1:
            need_repath = true
        elif player_visible and _chase_repath_cooldown <= 0.0:
            need_repath = true
        elif not player_visible and _chase_repath_cooldown <= 0.0 and _path_index >= _path.size():
            need_repath = true
    if need_repath:
        _set_path(
            _level.world_to_grid(monster_pos),
            _level.world_to_grid(player_pos),
            "chase:player",
            player_pos,
            player_visible
        )
        _chase_repath_cooldown = 0.35 if player_visible else 0.65
    _follow_path(delta, move_speed)

    if player_visible and (_path.is_empty() or _path.size() <= 1):
        var to_player: Vector3 = player_pos - monster_pos
        to_player.y = 0.0
        if to_player.length() > 0.05:
            var direct_dir: Vector3 = to_player.normalized()
            velocity.x = lerp(velocity.x, direct_dir.x * move_speed, delta * acceleration)
            velocity.z = lerp(velocity.z, direct_dir.z * move_speed, delta * acceleration)
            _current_target = player_pos
            _has_current_target = true

func _update_attack(delta: float) -> void:
    _lunge_timer += delta
    var monster_pos: Vector3 = global_transform.origin
    var player_pos: Vector3 = _player.global_transform.origin
    var direction: Vector3 = (player_pos - monster_pos).normalized()
    velocity.x = direction.x * lunge_speed
    velocity.z = direction.z * lunge_speed
    if monster_pos.distance_to(player_pos) < attack_distance * 0.9:
        emit_signal("player_caught")
        _state = "STALK"
        _path = PackedVector3Array()
        return
    if _lunge_timer >= lunge_time:
        _state = "CHASE"

func _follow_path(delta: float, target_speed: float) -> void:
    if _path.is_empty():
        velocity.x = lerp(velocity.x, 0.0, delta * acceleration)
        velocity.z = lerp(velocity.z, 0.0, delta * acceleration)
        _current_target = Vector3.ZERO
        _has_current_target = false
        return
    if _path_index >= _path.size():
        _path_index = _path.size() - 1
    var target: Vector3 = _path[_path_index]
    target.y = global_transform.origin.y
    if global_transform.origin.distance_to(target) < 0.6:
        _path_index += 1
        if _path_index >= _path.size():
            velocity.x = lerp(velocity.x, 0.0, delta * acceleration)
            velocity.z = lerp(velocity.z, 0.0, delta * acceleration)
            _current_target = Vector3.ZERO
            _has_current_target = false
            return
        target = _path[_path_index]
        target.y = global_transform.origin.y
    var direction: Vector3 = (target - global_transform.origin).normalized()
    velocity.x = lerp(velocity.x, direction.x * target_speed, delta * acceleration)
    velocity.z = lerp(velocity.z, direction.z * target_speed, delta * acceleration)
    _current_target = target
    _has_current_target = true

func _choose_hiding_destination(player_pos: Vector3) -> void:
    var player_cell: Vector2i = _level.world_to_grid(player_pos)
    var origin_cell: Vector2i = _level.world_to_grid(global_transform.origin)
    var target_cell: Vector2i = _level.get_random_cell_near(player_cell, 6, true, player_pos)
    if target_cell == origin_cell:
        target_cell = _level.get_random_cell_near(origin_cell, 8, false, player_pos)
    if target_cell == origin_cell:
        target_cell = _level.get_random_distant_cell(origin_cell, 4)
    _set_path(origin_cell, target_cell, "stalk:wander")
    if _path.size() <= 1:
        target_cell = _level.get_random_distant_cell(origin_cell, 2)
        _set_path(origin_cell, target_cell, "stalk:backup")

func _player_is_visible() -> bool:
    var from_pos: Vector3 = global_transform.origin + Vector3.UP * 1.6
    var to_pos: Vector3 = _player.global_transform.origin + Vector3.UP * 1.5
    return _level.has_line_of_sight_world(from_pos, to_pos, [self, _player])

func _enter_chase() -> void:
    _state = "CHASE"
    _time_since_seen = 0.0
    _path = PackedVector3Array()
    _path_index = 0
    _current_target = Vector3.ZERO
    _has_current_target = false
    _last_repath_reason = ""
    _chase_repath_cooldown = 0.0

func _enter_attack() -> void:
    _state = "ATTACK"
    _lunge_timer = 0.0

func _teleport_closer() -> void:
    var player_cell: Vector2i = _level.world_to_grid(_player.global_transform.origin)
    var spawn_cell: Vector2i = _level.get_random_cell_near(player_cell, 5, true, _player.global_transform.origin)
    var xf: Transform3D = global_transform
    xf.origin = _level.grid_to_world(spawn_cell) + Vector3(0, 0.2, 0)
    global_transform = xf
    _path = PackedVector3Array()
    _path_index = 0
    _current_target = Vector3.ZERO
    _has_current_target = false
    _last_repath_reason = "teleport"

func _on_player_noise(strength: float) -> void:
    if strength <= 0.01:
        return
    _noise_timer = noise_memory_time
    var player_pos: Vector3 = _player.global_transform.origin
    _last_noise_position = player_pos
    if _state == "STALK" or _state == "CHASE":
        _set_path(
            _level.world_to_grid(global_transform.origin),
            _level.world_to_grid(player_pos),
            "noise",
            player_pos,
            true
        )

func _process(delta: float) -> void:
    if _noise_timer > 0.0:
        _noise_timer -= delta
    if _state == "STALK" and _noise_timer > 0.0:
        var target_cell: Vector2i = _level.world_to_grid(_last_noise_position)
        _set_path(
            _level.world_to_grid(global_transform.origin),
            target_cell,
            "noise_memory",
            _last_noise_position,
            true
        )

func _set_path(
        from_cell: Vector2i,
        to_cell: Vector2i,
        reason: String,
        final_world_target: Vector3 = Vector3.ZERO,
        include_final_target: bool = false
    ) -> void:
    if not _level:
        return
    var new_path: PackedVector3Array = _level.find_path(from_cell, to_cell)
    if include_final_target:
        if new_path.is_empty():
            new_path.append(final_world_target)
        else:
            var last_index: int = new_path.size() - 1
            if new_path[last_index].distance_to(final_world_target) > 0.05:
                new_path.append(final_world_target)
            else:
                new_path[last_index] = final_world_target
    _path = new_path
    _path_index = 0
    _last_path_debug = _level.get_last_path_debug()
    _last_repath_reason = reason
    _current_target = Vector3.ZERO
    _has_current_target = false
    _stuck_timer = 0.0

func _handle_stuck() -> void:
    _stuck_timer = 0.0
    if not _level or not _player:
        return
    var origin_cell: Vector2i = _level.world_to_grid(global_transform.origin)
    match _state:
        "CHASE":
            _set_path(
                origin_cell,
                _level.world_to_grid(_player.global_transform.origin),
                "stuck:repath_player",
                _player.global_transform.origin,
                true
            )
            _chase_repath_cooldown = 0.3
        "STALK":
            _choose_hiding_destination(_player.global_transform.origin)
        _:
            pass

func get_path_points() -> PackedVector3Array:
    var copy: PackedVector3Array = PackedVector3Array()
    copy.append_array(_path)
    return copy
