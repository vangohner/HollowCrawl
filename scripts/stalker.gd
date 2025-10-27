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
var _sway_time: float = 0.0

@onready var _body_mesh: Node3D = $Body

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

    match _state:
        "STALK":
            _update_stalk(delta)
        "CHASE":
            _update_chase(delta)
        "ATTACK":
            _update_attack(delta)

    move_and_slide()

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

    if _player_is_visible():
        _time_since_seen = 0.0
        if distance <= attack_distance * 1.2:
            _enter_attack()
            return
    elif _time_since_seen > patience_time:
        _state = "STALK"
        return

    if _path.is_empty() or _time_since_seen < 0.3:
        _path = _level.find_path(_level.world_to_grid(monster_pos), _level.world_to_grid(player_pos))
        _path_index = 0
    _follow_path(delta, move_speed)

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
        return
    if _path_index >= _path.size():
        _path_index = _path.size() - 1
    var target: Vector3 = _path[_path_index]
    if global_transform.origin.distance_to(target) < 0.6:
        _path_index += 1
        if _path_index >= _path.size():
            velocity.x = lerp(velocity.x, 0.0, delta * acceleration)
            velocity.z = lerp(velocity.z, 0.0, delta * acceleration)
            return
        target = _path[_path_index]
    var direction: Vector3 = (target - global_transform.origin).normalized()
    velocity.x = lerp(velocity.x, direction.x * target_speed, delta * acceleration)
    velocity.z = lerp(velocity.z, direction.z * target_speed, delta * acceleration)

func _choose_hiding_destination(player_pos: Vector3) -> void:
    var player_cell: Vector2i = _level.world_to_grid(player_pos)
    var target_cell: Vector2i = _level.get_random_cell_near(player_cell, 6, true, player_pos)
    _path = _level.find_path(_level.world_to_grid(global_transform.origin), target_cell)
    _path_index = 0

func _player_is_visible() -> bool:
    var from_pos: Vector3 = global_transform.origin + Vector3.UP * 1.6
    var to_pos: Vector3 = _player.global_transform.origin + Vector3.UP * 1.5
    return _level.has_line_of_sight_world(from_pos, to_pos, [self, _player])

func _enter_chase() -> void:
    _state = "CHASE"
    _time_since_seen = 0.0
    _path = PackedVector3Array()
    _path_index = 0

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

func _on_player_noise(strength: float) -> void:
    if strength <= 0.01:
        return
    _noise_timer = noise_memory_time
    var player_pos: Vector3 = _player.global_transform.origin
    _last_noise_position = player_pos
    if _state == "STALK" or _state == "CHASE":
        _path = _level.find_path(_level.world_to_grid(global_transform.origin), _level.world_to_grid(player_pos))
        _path_index = 0

func _process(delta: float) -> void:
    if _noise_timer > 0.0:
        _noise_timer -= delta
    if _state == "STALK" and _noise_timer > 0.0:
        var target_cell: Vector2i = _level.world_to_grid(_last_noise_position)
        _path = _level.find_path(_level.world_to_grid(global_transform.origin), target_cell)
        _path_index = 0
    _sway_time += delta * (1.5 if _state == "STALK" else 3.0)
    if _body_mesh:
        _body_mesh.rotation_degrees.x = sin(_sway_time * 0.9) * 6.0
        _body_mesh.rotation_degrees.z = cos(_sway_time * 1.3) * 8.0
