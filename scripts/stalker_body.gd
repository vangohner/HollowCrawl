extends Node3D

class_name StalkerBody

@export var step_distance: float = 0.9
@export var step_height: float = 0.45
@export var step_duration: float = 0.32
@export var idle_sway_amplitude: float = 0.12
@export var idle_sway_speed: float = 0.8
@export var leg_recenter_speed: float = 6.0
@export var min_step_speed: float = 0.4
@export var stomp_intensity: float = 1.4

class LegData:
    var node: StalkerLeg
    var target: Vector3
    var current: Vector3
    var stepping: bool = false
    var timer: float = 0.0
    var step_offset: float = 0.0

var _legs: Array[LegData] = []
var _sway_time: float = 0.0
var _direct_space_state: PhysicsDirectSpaceState3D

@onready var _footsteps: FootstepPlayer = $Footsteps

func _ready() -> void:
    _direct_space_state = get_world_3d().direct_space_state
    for child in get_children():
        if child is StalkerLeg:
            var data := LegData.new()
            data.node = child
            var home_world: Vector3 = child.get_world_home_position(global_transform)
            data.current = home_world
            data.target = home_world
            data.step_offset = child.step_phase
            _legs.append(data)

func update_motion(parent_velocity: Vector3, delta: float, on_floor: bool) -> void:
    if _direct_space_state == null and get_world_3d():
        _direct_space_state = get_world_3d().direct_space_state
    _sway_time += delta
    var body_xform: Transform3D = global_transform
    if not on_floor:
        _apply_idle_sway(delta)
        return
    for leg in _legs:
        var desired: Vector3 = leg.node.get_world_home_position(body_xform)
        desired += -parent_velocity * 0.1
        desired = _project_to_floor(desired)
        if not leg.stepping:
            var distance_from_current: float = leg.current.distance_to(desired)
            var moving_fast: bool = parent_velocity.length() > min_step_speed
            if distance_from_current > step_distance or (moving_fast and _should_step_now(leg, delta)):
                leg.stepping = true
                leg.timer = 0.0
                leg.target = desired
        if leg.stepping:
            leg.timer += delta
            var t: float = min(leg.timer / step_duration, 1.0)
            var eased: float = sin(t * PI * 0.5)
            var foot_pos: Vector3 = leg.current.lerp(leg.target, eased)
            var arc: float = sin(t * PI)
            foot_pos.y += arc * step_height
            leg.current = foot_pos
            leg.node.foot.global_transform = Transform3D(leg.node.foot.global_transform.basis, foot_pos)
            if t >= 1.0:
                leg.current = leg.target
                leg.stepping = false
                _play_step_sound(parent_velocity.length())
        else:
            leg.current = leg.current.lerp(desired, delta * leg_recenter_speed)
            leg.node.foot.global_transform = Transform3D(leg.node.foot.global_transform.basis, leg.current)
        _solve_leg(leg)
    _apply_idle_sway(delta)

func _should_step_now(leg: LegData, delta: float) -> bool:
    var cycle: float = fposmod(_sway_time * idle_sway_speed + leg.step_offset, TAU)
    return cycle < delta * idle_sway_speed * PI

func _project_to_floor(world_point: Vector3) -> Vector3:
    if _direct_space_state == null:
        return world_point
    var query := PhysicsRayQueryParameters3D.create(world_point + Vector3.UP * 1.5, world_point + Vector3.DOWN * 2.5)
    query.exclude = [get_parent()]
    var result: Dictionary = _direct_space_state.intersect_ray(query)
    if result.is_empty():
        return world_point
    return result.position

func _solve_leg(leg: LegData) -> void:
    var leg_node := leg.node
    var pivot := leg_node.pivot
    var upper := leg_node.upper
    var lower := leg_node.lower
    var foot := leg_node.foot
    var pivot_origin: Vector3 = pivot.global_transform.origin
    var to_target: Vector3 = leg.current - pivot_origin
    var horizontal: Vector3 = Vector3(to_target.x, 0.0, to_target.z)
    if horizontal.length() > 0.0001:
        var desired_yaw: float = atan2(horizontal.x, horizontal.z)
        pivot.rotation.y = lerp_angle(pivot.rotation.y, desired_yaw, 0.5)
    var target_local: Vector3 = upper.to_local(leg.current)
    var planar: Vector2 = Vector2(target_local.z, -target_local.y)
    var dist: float = clampf(planar.length(), 0.05, leg_node.upper_length + leg_node.lower_length - 0.05)
    var angle_to_target: float = atan2(planar.y, planar.x)
    var upper_cos: float = clampf((leg_node.upper_length * leg_node.upper_length + dist * dist - leg_node.lower_length * leg_node.lower_length) / (2.0 * leg_node.upper_length * dist), -1.0, 1.0)
    var knee_cos: float = clampf((leg_node.upper_length * leg_node.upper_length + leg_node.lower_length * leg_node.lower_length - dist * dist) / (2.0 * leg_node.upper_length * leg_node.lower_length), -1.0, 1.0)
    var upper_angle: float = angle_to_target - acos(upper_cos)
    var knee_angle: float = PI - acos(knee_cos)
    upper.rotation.x = upper_angle
    lower.rotation.x = -knee_angle
    foot.rotation = Vector3.ZERO

func _apply_idle_sway(delta: float) -> void:
    var sway := sin(_sway_time * idle_sway_speed) * idle_sway_amplitude
    rotation.z = sway * 0.3
    rotation.x = cos(_sway_time * idle_sway_speed * 0.7) * idle_sway_amplitude * 0.5

func _play_step_sound(speed: float) -> void:
    if not _footsteps:
        return
    var intensity: float = clampf(remap(speed, 0.0, 6.0, 0.6, stomp_intensity), 0.6, stomp_intensity)
    _footsteps.play_step(intensity)
