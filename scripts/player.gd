extends CharacterBody3D

@export var walk_speed := 3.5
@export var run_speed := 6.5
@export var acceleration := 8.0
@export var gravity := 24.0
@export var stamina_max := 6.0
@export var stamina_recovery_rate := 1.8
@export var stamina_drain_rate := 2.2
@export var stamina_recovery_delay := 1.2
@export var mouse_sensitivity := 0.08
@export var head_bob_amount := 0.08
@export var head_bob_speed := 6.0
@export var sway_amount := 1.5
@export var sway_smooth := 6.0

signal noise_emitted(strength: float)
signal stamina_changed(value: float)

var stamina := stamina_max
var _recovery_timer := 0.0
var _head_bob_time := 0.0
var _flashlight_active := true

@onready var _camera: Camera3D = $Camera
@onready var _flashlight: SpotLight3D = $Camera/Flashlight
@onready var _breath: AudioStreamPlayer3D = $Breath

func _ready() -> void:
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    stamina = stamina_max
    emit_signal("stamina_changed", stamina / stamina_max)
    _flashlight.visible = _flashlight_active

func _input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
        var pitch := clampf(_camera.rotation_degrees.x - event.relative.y * mouse_sensitivity, -89.0, 89.0)
        _camera.rotation_degrees.x = pitch
    elif event.is_action_pressed("flashlight_toggle"):
        _flashlight_active = !_flashlight_active
        _flashlight.visible = _flashlight_active

func _physics_process(delta: float) -> void:
    var input_dir := Vector3.ZERO
    input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
    input_dir.z = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
    input_dir = input_dir.normalized()

    if not is_on_floor():
        velocity.y -= gravity * delta
    else:
        velocity.y = 0.0

    var target_speed := walk_speed
    var is_running := false
    if Input.is_action_pressed("run") and stamina > 0.1 and input_dir.length() > 0.0:
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

    var basis := global_transform.basis
    var forward := -basis.z
    var right := basis.x

    var target_velocity := (forward * input_dir.z + right * input_dir.x) * target_speed
    velocity.x = lerp(velocity.x, target_velocity.x, acceleration * delta)
    velocity.z = lerp(velocity.z, target_velocity.z, acceleration * delta)

    move_and_slide()

    _update_head_bob(delta, target_speed, input_dir.length())
    _update_sway(delta)

    var movement_intensity := clampf(target_velocity.length() / run_speed, 0.0, 1.0)
    if movement_intensity > 0.1:
        emit_signal("noise_emitted", 0.4 + movement_intensity * (1.2 if is_running else 0.6))
    else:
        emit_signal("noise_emitted", 0.1)

func _update_head_bob(delta: float, target_speed: float, movement_amount: float) -> void:
    if movement_amount < 0.1 or not is_on_floor():
        _head_bob_time = lerp(_head_bob_time, 0.0, delta * 5.0)
        _camera.translation = _camera.translation.lerp(Vector3.ZERO, delta * 6.0)
        return

    _head_bob_time += delta * head_bob_speed * movement_amount * clamp(target_speed / run_speed, 0.5, 1.0)
    var bob_offset := Vector3(0.0, sin(_head_bob_time) * head_bob_amount, 0.0)
    _camera.translation = _camera.translation.lerp(bob_offset, delta * 10.0)

func _update_sway(delta: float) -> void:
    var mouse_pos := get_viewport().get_mouse_position()
    var viewport := get_viewport()
    if viewport and viewport.size.x > 0:
        var center := viewport.size / 2.0
        var offset := (mouse_pos - center) / center
        var sway := Vector3(-offset.y, -offset.x, 0.0) * sway_amount
        _camera.rotation = _camera.rotation.lerp(Vector3(deg_to_rad(sway.x), deg_to_rad(sway.y), 0.0), delta * sway_smooth)

func apply_shake(amount: float) -> void:
    _head_bob_time += amount * 0.5

func on_monster_close() -> void:
    if _breath.stream and not _breath.playing:
        _breath.pitch_scale = randf_range(0.85, 1.1)
        _breath.play()
