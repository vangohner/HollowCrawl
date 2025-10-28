class_name PathVisualizer
extends Node3D

@export var path_color: Color = Color(0.4, 0.85, 1.0, 1.0)
@export var waypoint_color: Color = Color(0.95, 0.95, 0.7, 1.0)
@export var velocity_color: Color = Color(1.0, 0.35, 0.2, 1.0)
@export var waypoint_height: float = 0.45
@export var velocity_max_length: float = 6.0

var _path_mesh: ImmediateMesh = ImmediateMesh.new()
var _waypoint_mesh: ImmediateMesh = ImmediateMesh.new()
var _velocity_mesh: ImmediateMesh = ImmediateMesh.new()
var _path_instance: MeshInstance3D
var _waypoint_instance: MeshInstance3D
var _velocity_instance: MeshInstance3D

func _ready() -> void:
    _path_instance = MeshInstance3D.new()
    _path_instance.mesh = _path_mesh
    add_child(_path_instance)

    _waypoint_instance = MeshInstance3D.new()
    _waypoint_instance.mesh = _waypoint_mesh
    add_child(_waypoint_instance)

    _velocity_instance = MeshInstance3D.new()
    _velocity_instance.mesh = _velocity_mesh
    add_child(_velocity_instance)

    visible = false

func clear() -> void:
    _path_mesh.clear_surfaces()
    _waypoint_mesh.clear_surfaces()
    _velocity_mesh.clear_surfaces()

func update_debug(points: PackedVector3Array, stalker_height: float, origin: Vector3, velocity: Vector3) -> void:
    _rebuild_path(points, stalker_height)
    _rebuild_velocity(origin, velocity, stalker_height)

func _rebuild_path(points: PackedVector3Array, stalker_height: float) -> void:
    _path_mesh.clear_surfaces()
    _waypoint_mesh.clear_surfaces()
    if points.size() == 0:
        return

    if points.size() == 1:
        _path_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
        _path_mesh.surface_set_color(path_color)
        var point: Vector3 = points[0]
        var vertex: Vector3 = Vector3(point.x, stalker_height, point.z)
        _path_mesh.surface_add_vertex(vertex + Vector3(0, -0.1, 0))
        _path_mesh.surface_add_vertex(vertex + Vector3(0, 0.1, 0))
        _path_mesh.surface_end()
    else:
        _path_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
        _path_mesh.surface_set_color(path_color)
        for i in range(points.size()):
            var p: Vector3 = points[i]
            _path_mesh.surface_add_vertex(Vector3(p.x, stalker_height, p.z))
        _path_mesh.surface_end()

    _waypoint_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
    _waypoint_mesh.surface_set_color(waypoint_color)
    for i in range(points.size()):
        var point: Vector3 = points[i]
        var base: Vector3 = Vector3(point.x, stalker_height, point.z)
        _waypoint_mesh.surface_add_vertex(base + Vector3(0, -0.1, 0))
        _waypoint_mesh.surface_add_vertex(base + Vector3(0, waypoint_height, 0))
    _waypoint_mesh.surface_end()

func _rebuild_velocity(origin: Vector3, velocity: Vector3, stalker_height: float) -> void:
    _velocity_mesh.clear_surfaces()
    var planar_velocity: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
    if planar_velocity.length() < 0.01:
        return
    var scaled: Vector3 = planar_velocity
    if scaled.length() > velocity_max_length:
        scaled = scaled.normalized() * velocity_max_length
    _velocity_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
    _velocity_mesh.surface_set_color(velocity_color)
    var start: Vector3 = Vector3(origin.x, stalker_height, origin.z)
    var end_point: Vector3 = start + scaled
    _velocity_mesh.surface_add_vertex(start)
    _velocity_mesh.surface_add_vertex(end_point)
    _velocity_mesh.surface_end()
