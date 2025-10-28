extends Node3D

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

@export var cell_size: float = 6.0
@export var wall_height: float = 4.0
@export var wall_thickness: float = 0.5
@export var floor_thickness: float = 0.25
@export var ceiling_thickness: float = 0.25
@export var map_layout: Array[String] = [
    "########################",
    "#....#...........#.....#",
    "#.##.#.#####.###.#.###.#",
    "#.#..#.....#...#.#...#.#",
    "#.#.#####.#.#.#.###.#.#",
    "#.#.....#.#.#.#.....#.#",
    "#.###.#.#.#.#.#####.#.#",
    "#.....#.#.#.#.....#.#.#",
    "#####.#.#.#.#####.#.#.#",
    "#.....#.#.#.....#.#.#.#",
    "#.###.#.#.#####.#.#.#.#",
    "#.#...#.#.....#.#.#.#.#",
    "#.#.###.#####.#.#.#.#.#",
    "#.#...........#.#.#...#",
    "#.#############.#.###.#",
    "#.................#...#",
    "########################"
]

var _walkable: Dictionary = {}
var _cells: Array[Vector2i] = []
var _space_state: PhysicsDirectSpaceState3D = null
var _last_path_debug: Dictionary = {}

func _ready() -> void:
    randomize()
    _space_state = get_world_3d().direct_space_state
    _generate_level()

func _generate_level() -> void:
    for y in range(map_layout.size()):
        var row: String = map_layout[y]
        for x in range(row.length()):
            var cell_char: String = row[x]
            var cell: Vector2i = Vector2i(x, y)
            if cell_char != '#':
                _walkable[cell] = true
                _cells.append(cell)
                _create_floor(cell)
                _create_ceiling(cell)
    for cell in _cells:
        _create_walls_for_cell(cell)
        if randi() % 4 == 0:
            _create_pipe(cell)
        if randi() % 6 == 0:
            _create_steam(cell)

func _create_floor(cell: Vector2i) -> void:
    var floor_body: StaticBody3D = StaticBody3D.new()
    floor_body.name = "Floor_%s_%s" % [cell.x, cell.y]
    var mesh_instance: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = Vector3(cell_size, floor_thickness, cell_size)
    mesh_instance.mesh = mesh
    mesh_instance.material_override = _create_floor_material()
    mesh_instance.position = Vector3(0, -floor_thickness * 0.5, 0)
    floor_body.add_child(mesh_instance)

    var collision: CollisionShape3D = CollisionShape3D.new()
    var shape: BoxShape3D = BoxShape3D.new()
    shape.size = Vector3(cell_size, floor_thickness, cell_size)
    collision.shape = shape
    collision.position = Vector3(0, -floor_thickness * 0.5, 0)
    floor_body.add_child(collision)

    floor_body.position = grid_to_world(cell)
    add_child(floor_body)

func _create_ceiling(cell: Vector2i) -> void:
    var ceiling_body: StaticBody3D = StaticBody3D.new()
    ceiling_body.name = "Ceiling_%s_%s" % [cell.x, cell.y]
    var mesh_instance: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = Vector3(cell_size, ceiling_thickness, cell_size)
    mesh_instance.mesh = mesh
    mesh_instance.material_override = _create_ceiling_material()
    mesh_instance.position = Vector3(0, ceiling_thickness * 0.5, 0)
    ceiling_body.add_child(mesh_instance)

    var collision: CollisionShape3D = CollisionShape3D.new()
    var shape: BoxShape3D = BoxShape3D.new()
    shape.size = Vector3(cell_size, ceiling_thickness, cell_size)
    collision.shape = shape
    collision.position = Vector3(0, ceiling_thickness * 0.5, 0)
    ceiling_body.add_child(collision)

    ceiling_body.position = grid_to_world(cell) + Vector3(0, wall_height, 0)
    add_child(ceiling_body)

func _create_walls_for_cell(cell: Vector2i) -> void:
    for dir in DIRECTIONS:
        var neighbor: Vector2i = cell + dir
        if not _walkable.has(neighbor):
            _create_wall_segment(cell, dir)

func _create_wall_segment(cell: Vector2i, dir: Vector2i) -> void:
    var wall: StaticBody3D = StaticBody3D.new()
    wall.name = "Wall_%s_%s_%s_%s" % [cell.x, cell.y, dir.x, dir.y]
    var mesh_instance: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    var size: Vector3 = Vector3.ZERO
    if dir.x == 0:
        size = Vector3(cell_size, wall_height, wall_thickness)
    else:
        size = Vector3(wall_thickness, wall_height, cell_size)
    mesh.size = size
    mesh_instance.mesh = mesh
    mesh_instance.material_override = _create_wall_material()
    wall.add_child(mesh_instance)

    var collision: CollisionShape3D = CollisionShape3D.new()
    var shape: BoxShape3D = BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    wall.add_child(collision)

    var offset: Vector3 = Vector3.ZERO
    if dir == Vector2i.UP:
        offset = Vector3(0, wall_height / 2.0, -cell_size / 2.0)
    elif dir == Vector2i.DOWN:
        offset = Vector3(0, wall_height / 2.0, cell_size / 2.0)
    elif dir == Vector2i.LEFT:
        offset = Vector3(-cell_size / 2.0, wall_height / 2.0, 0)
    elif dir == Vector2i.RIGHT:
        offset = Vector3(cell_size / 2.0, wall_height / 2.0, 0)

    wall.position = grid_to_world(cell) + offset
    add_child(wall)

func _create_pipe(cell: Vector2i) -> void:
    var blocked_dirs: Array[Vector2i] = []
    for dir in DIRECTIONS:
        if not _walkable.has(cell + dir):
            blocked_dirs.append(dir)
    if blocked_dirs.is_empty():
        return
    var facing: Vector2i = blocked_dirs[randi() % blocked_dirs.size()]
    var pipe: MeshInstance3D = MeshInstance3D.new()
    pipe.name = "Pipe_%s_%s" % [cell.x, cell.y]
    var pipe_mesh: CylinderMesh = CylinderMesh.new()
    pipe_mesh.radius = 0.22
    pipe_mesh.height = wall_height - floor_thickness * 0.5
    pipe.mesh = pipe_mesh
    pipe.material_override = _create_pipe_material()
    var offset: Vector3 = Vector3.ZERO
    var inset: float = cell_size * 0.5 - 0.35
    if facing == Vector2i.UP:
        offset = Vector3(0, pipe_mesh.height * 0.5, -inset)
    elif facing == Vector2i.DOWN:
        offset = Vector3(0, pipe_mesh.height * 0.5, inset)
    elif facing == Vector2i.LEFT:
        offset = Vector3(-inset, pipe_mesh.height * 0.5, 0)
    else:
        offset = Vector3(inset, pipe_mesh.height * 0.5, 0)
    pipe.position = grid_to_world(cell) + offset
    add_child(pipe)

func _create_steam(cell: Vector2i) -> void:
    var particles: GPUParticles3D = GPUParticles3D.new()
    particles.name = "Steam_%s_%s" % [cell.x, cell.y]
    particles.amount = 96
    particles.lifetime = 2.8
    particles.one_shot = false
    particles.emitting = true
    particles.speed_scale = 0.8
    particles.process_material = _create_steam_material()
    particles.position = grid_to_world(cell) + Vector3(randf_range(-1.2, 1.2), 0.2, randf_range(-1.2, 1.2))
    add_child(particles)

func _create_floor_material() -> StandardMaterial3D:
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.albedo_color = Color(0.06, 0.06, 0.065, 1)
    mat.roughness = 1.0
    mat.metallic = 0.1
    # Detail channels expect texture inputs; omit to avoid type mismatches when using plain colors.
    return mat

func _create_wall_material() -> StandardMaterial3D:
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.albedo_color = Color(0.08, 0.08, 0.09, 1)
    mat.roughness = 0.9
    mat.metallic = 0.05
    # Detail channels expect texture inputs; omit to avoid type mismatches when using plain colors.
    return mat

func _create_ceiling_material() -> StandardMaterial3D:
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.albedo_color = Color(0.05, 0.05, 0.055, 1)
    mat.roughness = 0.95
    mat.metallic = 0.02
    return mat

func _create_pipe_material() -> StandardMaterial3D:
    var mat: StandardMaterial3D = StandardMaterial3D.new()
    mat.albedo_color = Color(0.32, 0.34, 0.36, 1)
    mat.metallic = 0.8
    mat.roughness = 0.3
    return mat

func _create_steam_material() -> ParticleProcessMaterial:
    var mat: ParticleProcessMaterial = ParticleProcessMaterial.new()
    mat.emission_box_extents = Vector3(0.6, 0.1, 0.6)
    mat.gravity = Vector3(0, 0.0, 0)
    mat.initial_velocity_min = 0.2
    mat.initial_velocity_max = 0.9
    mat.angular_velocity_min = -0.6
    mat.angular_velocity_max = 0.6
    mat.scale_min = 0.5
    mat.scale_max = 1.1
    var scale_curve: Curve = Curve.new()
    scale_curve.add_point(Vector2(0.0, 0.0))
    scale_curve.add_point(Vector2(0.4, 0.6))
    scale_curve.add_point(Vector2(1.0, 1.0))
    var curve_texture: CurveTexture = CurveTexture.new()
    curve_texture.curve = scale_curve
    mat.scale_curve = curve_texture
    mat.color = Color(0.75, 0.76, 0.8, 0.42)
    return mat

func grid_to_world(cell: Vector2i) -> Vector3:
    return Vector3(cell.x * cell_size, 0, cell.y * cell_size)

func world_to_grid(world: Vector3) -> Vector2i:
    return Vector2i(roundi(world.x / cell_size), roundi(world.z / cell_size))

func is_walkable(cell: Vector2i) -> bool:
    return _walkable.has(cell)

func find_path(start: Vector2i, goal: Vector2i) -> PackedVector3Array:
    var debug: Dictionary = {
        "requested_start": start,
        "requested_goal": goal,
        "start_valid": _walkable.has(start),
        "goal_valid": _walkable.has(goal),
        "start_adjust_steps": 0,
        "goal_adjust_steps": 0,
        "actual_start": start,
        "actual_goal": goal,
        "found": false,
        "path_length": 0,
        "cells": []
    }

    var actual_start_result: Dictionary = _find_nearest_walkable(start)
    var actual_goal_result: Dictionary = _find_nearest_walkable(goal)
    debug["start_adjust_steps"] = actual_start_result.get("steps", 0)
    debug["goal_adjust_steps"] = actual_goal_result.get("steps", 0)
    var actual_start: Vector2i = actual_start_result.get("cell", start)
    var actual_goal: Vector2i = actual_goal_result.get("cell", goal)
    debug["actual_start"] = actual_start
    debug["actual_goal"] = actual_goal

    if not _walkable.has(actual_start) or not _walkable.has(actual_goal):
        _last_path_debug = debug
        return PackedVector3Array()

    var frontier: Array[Vector2i] = [actual_start]
    var came_from: Dictionary = {actual_start: actual_start}
    while frontier:
        var current: Vector2i = frontier.pop_front()
        if current == actual_goal:
            break
        for dir in DIRECTIONS:
            var neighbor: Vector2i = current + dir
            if _walkable.has(neighbor) and not came_from.has(neighbor):
                frontier.append(neighbor)
                came_from[neighbor] = current
    if not came_from.has(actual_goal):
        _last_path_debug = debug
        return PackedVector3Array()
    var cells: Array[Vector2i] = []
    var cursor: Vector2i = actual_goal
    while true:
        cells.insert(0, cursor)
        if cursor == actual_start:
            break
        cursor = came_from[cursor]
    var result: PackedVector3Array = PackedVector3Array()
    for c in cells:
        result.append(grid_to_world(c))
    debug["found"] = true
    debug["path_length"] = result.size()
    debug["cells"] = cells.duplicate()
    _last_path_debug = debug
    return result

func _find_nearest_walkable(cell: Vector2i) -> Dictionary:
    var visited: Dictionary = {cell: true}
    var frontier: Array[Vector2i] = [cell]
    var steps: Dictionary = {cell: 0}
    while frontier:
        var current: Vector2i = frontier.pop_front()
        if _walkable.has(current):
            return {"cell": current, "steps": steps.get(current, 0)}
        var distance: int = steps.get(current, 0) + 1
        for dir in DIRECTIONS:
            var neighbor: Vector2i = current + dir
            if visited.has(neighbor):
                continue
            visited[neighbor] = true
            steps[neighbor] = distance
            frontier.append(neighbor)
    return {"cell": cell, "steps": -1}

func get_random_cell_near(center: Vector2i, radius: int, require_cover: bool = false, threat_origin: Vector3 = Vector3.ZERO) -> Vector2i:
    var candidates: Array[Vector2i] = []
    var center_pos: Vector2 = Vector2(center.x, center.y)
    for cell in _cells:
        var cell_pos: Vector2 = Vector2(cell.x, cell.y)
        if cell_pos.distance_to(center_pos) <= float(radius) and _walkable.has(cell):
            if not require_cover or not has_line_of_sight_world(grid_to_world(cell) + Vector3.UP * 1.4, threat_origin):
                candidates.append(cell)
    if candidates.is_empty():
        return center
    candidates.shuffle()
    for candidate in candidates:
        if candidate != center:
            return candidate
    return candidates[0]

func get_random_distant_cell(origin: Vector2i, min_distance: int = 4) -> Vector2i:
    var options: Array[Vector2i] = []
    var origin_pos: Vector2 = Vector2(origin.x, origin.y)
    for cell in _cells:
        if cell == origin:
            continue
        var distance: float = Vector2(cell.x, cell.y).distance_to(origin_pos)
        if distance >= float(min_distance):
            options.append(cell)
    if options.is_empty():
        return origin
    options.shuffle()
    return options[0]

func has_line_of_sight_world(from_pos: Vector3, to_pos: Vector3, exclude: Array = []) -> bool:
    if not _space_state:
        _space_state = get_world_3d().direct_space_state
    var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
    var exclude_rids: Array[RID] = []
    for item in exclude:
        if item is CollisionObject3D:
            exclude_rids.append(item.get_rid())
        elif typeof(item) == TYPE_RID:
            exclude_rids.append(item)
    params.exclude = exclude_rids
    params.collision_mask = 0xFFFFFFFF
    var result: Dictionary = _space_state.intersect_ray(params)
    return result.is_empty()

func get_cells() -> Array[Vector2i]:
    return _cells.duplicate()

func get_last_path_debug() -> Dictionary:
    return _last_path_debug.duplicate(true)
