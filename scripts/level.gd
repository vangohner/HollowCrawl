extends Node3D

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

@export var cell_size: float = 6.0
@export var wall_height: float = 4.0
@export var wall_thickness: float = 0.5
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
    for cell in _cells:
        _create_walls_for_cell(cell)
        if randi() % 4 == 0:
            _create_pipe(cell)
        if randi() % 6 == 0:
            _create_steam(cell)

func _create_floor(cell: Vector2i) -> void:
    var floor: StaticBody3D = StaticBody3D.new()
    floor.name = "Floor_%s_%s" % [cell.x, cell.y]
    var mesh_instance: MeshInstance3D = MeshInstance3D.new()
    var mesh: BoxMesh = BoxMesh.new()
    mesh.size = Vector3(cell_size, 0.2, cell_size)
    mesh_instance.mesh = mesh
    mesh_instance.material_override = _create_floor_material()
    mesh_instance.translation = Vector3(0, -0.6, 0)
    floor.add_child(mesh_instance)

    var collision: CollisionShape3D = CollisionShape3D.new()
    var shape: BoxShape3D = BoxShape3D.new()
    shape.size = Vector3(cell_size, 0.2, cell_size)
    collision.shape = shape
    collision.translation = Vector3.ZERO
    floor.add_child(collision)

    floor.translation = grid_to_world(cell)
    add_child(floor)

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

    wall.translation = grid_to_world(cell) + offset
    add_child(wall)

func _create_pipe(cell: Vector2i) -> void:
    var pipe: MeshInstance3D = MeshInstance3D.new()
    pipe.name = "Pipe_%s_%s" % [cell.x, cell.y]
    var pipe_mesh: CylinderMesh = CylinderMesh.new()
    pipe_mesh.radius = 0.18
    pipe_mesh.height = cell_size * 0.9
    pipe.mesh = pipe_mesh
    pipe.material_override = _create_pipe_material()
    pipe.rotation_degrees = Vector3(90, 0, randf_range(-12, 12))
    pipe.translation = grid_to_world(cell) + Vector3(randf_range(-cell_size * 0.3, cell_size * 0.3), wall_height * 0.6, -cell_size / 2.0 + 0.4)
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
    particles.translation = grid_to_world(cell) + Vector3(randf_range(-1.2, 1.2), 0.2, randf_range(-1.2, 1.2))
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
    scale_curve.add_point(0.0, 0.0)
    scale_curve.add_point(0.4, 0.6)
    scale_curve.add_point(1.0, 1.0)
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
    if not _walkable.has(start) or not _walkable.has(goal):
        return PackedVector3Array()
    var frontier: Array[Vector2i] = [start]
    var came_from: Dictionary = {start: start}
    while frontier:
        var current: Vector2i = frontier.pop_front()
        if current == goal:
            break
        for dir in DIRECTIONS:
            var neighbor: Vector2i = current + dir
            if _walkable.has(neighbor) and not came_from.has(neighbor):
                frontier.append(neighbor)
                came_from[neighbor] = current
    if not came_from.has(goal):
        return PackedVector3Array()
    var cells: Array[Vector2i] = []
    var cursor: Vector2i = goal
    while true:
        cells.insert(0, cursor)
        if cursor == start:
            break
        cursor = came_from[cursor]
    var result: PackedVector3Array = PackedVector3Array()
    for c in cells:
        result.append(grid_to_world(c))
    return result

func get_random_cell_near(center: Vector2i, radius: int, require_cover: bool = false, threat_origin: Vector3 = Vector3.ZERO) -> Vector2i:
    var candidates: Array[Vector2i] = []
    for cell in _cells:
        var cell_pos: Vector2 = cell.to_vector2()
        if cell_pos.distance_to(center.to_vector2()) <= float(radius) and _walkable.has(cell):
            if not require_cover or not has_line_of_sight_world(grid_to_world(cell) + Vector3.UP * 1.4, threat_origin):
                candidates.append(cell)
    if candidates.is_empty():
        return center
    candidates.shuffle()
    return candidates[0]

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
