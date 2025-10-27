extends CharacterBody3D

@export var walk_speed: float = 3.5
@export var run_speed: float = 6.5
@export var acceleration: float = 8.0
@export var gravity: float = 24.0
@export var stamina_max: float = 6.0
@export var stamina_recovery_rate: float = 1.8
@export var stamina_drain_rate: float = 2.2
@export var stamina_recovery_delay: float = 1.2
@export var mouse_sensitivity: float = 0.08
@export var head_bob_amount: float = 0.08
@export var head_bob_speed: float = 6.0
@export var sway_amount: float = 1.5
@export var sway_smooth: float = 6.0

signal noise_emitted(strength: float)
signal stamina_changed(value: float)

var stamina: float = stamina_max
var _recovery_timer: float = 0.0
var _head_bob_time: float = 0.0
var _flashlight_active: bool = true
var _camera_pitch_deg: float = 0.0
var _camera_base_rotation: Vector3 = Vector3.ZERO
var _sway_rotation: Vector3 = Vector3.ZERO

@onready var _camera: Camera3D = $Camera
@onready var _flashlight: SpotLight3D = $Camera/Flashlight
@onready var _breath: BreathPlayer = $Breath

func _ready() -> void:
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    stamina = stamina_max
    emit_signal("stamina_changed", stamina / stamina_max)
    _flashlight.visible = _flashlight_active
    _camera_base_rotation = _camera.rotation_degrees
    _camera_pitch_deg = _camera_base_rotation.x
    _apply_camera_rotation()

func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
        _camera_pitch_deg = clampf(_camera_pitch_deg - event.relative.y * mouse_sensitivity, -89.0, 89.0)
        _apply_camera_rotation()
    elif event.is_action_pressed("flashlight_toggle"):
        _flashlight_active = !_flashlight_active
        _flashlight.visible = _flashlight_active

func _physics_process(delta: float) -> void:
    var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
    var local_basis: Basis = global_transform.basis
    var forward: Vector3 = -local_basis.z
    var right: Vector3 = local_basis.x
    var move_direction: Vector3 = (right * input_vector.x) + (forward * -input_vector.y)
    var move_strength: float = move_direction.length()
    move_strength = clampf(move_strength, 0.0, 1.0)
    if move_strength > 0.0:
        move_direction /= move_strength

    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = 0.0

    var target_speed: float = walk_speed
    var is_running: bool = false
    if Input.is_action_pressed("run") and stamina > 0.1 and move_strength > 0.0:
        target_speed = run_speed
        stamina = max(0.0, stamina - stamina_drain_rate * delta)
        _recovery_timer = 0.0
        is_running = true
    elif stamina < stamina_max:
        _recovery_timer += delta
        if _recovery_timer >= stamina_recovery_delay:
            stamina = min(stamina_max, stamina + stamina_recovery_rate * delta)
    if Input.is_action_just_released("run"):
        _recovery_timer = 0.0

    emit_signal("stamina_changed", stamina / stamina_max)

    var target_velocity: Vector3 = move_direction * target_speed
    velocity.x = lerp(velocity.x, target_velocity.x, acceleration * delta)
    velocity.z = lerp(velocity.z, target_velocity.z, acceleration * delta)

    move_and_slide()

    _update_head_bob(delta, target_speed, move_strength)
    _update_sway(delta)

    var movement_intensity: float = clampf(target_velocity.length() / run_speed, 0.0, 1.0)
    if movement_intensity > 0.1:
        emit_signal("noise_emitted", 0.4 + movement_intensity * (1.2 if is_running else 0.6))
    else:
        emit_signal("noise_emitted", 0.1)

func _update_head_bob(delta: float, target_speed: float, movement_amount: float) -> void:
    if movement_amount < 0.1 or not is_on_floor():
        _head_bob_time = lerp(_head_bob_time, 0.0, delta * 5.0)
        _camera.position = _camera.position.lerp(Vector3.ZERO, delta * 6.0)
        return

    _head_bob_time += delta * head_bob_speed * movement_amount * clampf(target_speed / run_speed, 0.5, 1.0)
    var bob_offset: Vector3 = Vector3(0.0, sin(_head_bob_time) * head_bob_amount, 0.0)
    _camera.position = _camera.position.lerp(bob_offset, delta * 10.0)

func _update_sway(delta: float) -> void:
    var mouse_pos: Vector2 = get_viewport().get_mouse_position()
    var viewport: Viewport = get_viewport()
    if viewport and viewport.size.x > 0:
        var center: Vector2 = viewport.size / 2.0
        var offset: Vector2 = (mouse_pos - center) / center
        var sway: Vector3 = Vector3(-offset.y, -offset.x, 0.0) * sway_amount
        _sway_rotation = _sway_rotation.lerp(sway, delta * sway_smooth)
    else:
        _sway_rotation = _sway_rotation.lerp(Vector3.ZERO, delta * sway_smooth)
    _apply_camera_rotation()

func apply_shake(amount: float) -> void:
    _head_bob_time += amount * 0.5

func on_monster_close() -> void:
    if _breath.stream and not _breath.playing:
        _breath.pitch_scale = randf_range(0.85, 1.1)
        _breath.start_breath()

func _apply_camera_rotation() -> void:
    var base_rotation: Vector3 = _camera_base_rotation
    base_rotation.x = _camera_pitch_deg
    var target_rotation: Vector3 = base_rotation + _sway_rotation
    _camera.rotation_degrees = target_rotation
