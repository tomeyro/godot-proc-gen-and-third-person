extends Spatial


var map_size
var map_extra
var square_size
var min_height
var max_height
var center
var map_bottom

var max_distance

onready var mesh_instance: MeshInstance = $StaticBody/MeshInstance
onready var mesh_shape: CollisionShape = $StaticBody/CollisionShape

var noise: OpenSimplexNoise
var noise2: OpenSimplexNoise
var material: Material
var point_heights = {}

onready var player = $PlayerController/Player


func _ready() -> void:
    material = load("res://material.tres")

    randomize()
    _generate()

    DebugConsole.register_object("world", self)
    DebugConsole.register_object("player", player)


func _process(delta: float) -> void:
    if Input.is_action_just_pressed("ui_end"):
        _generate()


func _generate() -> void:
    map_size = 100
    map_extra = 50
    square_size = 3
    min_height = 1
    max_height = 100
    map_bottom = -30
    center = Vector2(map_size / 2.0, map_size / 2.0)

    DebugConsole.fix_message("Map Size", map_size)
    DebugConsole.fix_message("Map Extra", map_extra)
    DebugConsole.fix_message("Square Size", square_size)
    DebugConsole.fix_message("Min Height", min_height)
    DebugConsole.fix_message("Max Height", max_height)
    DebugConsole.fix_message("Map Bottom", map_bottom)

    noise = OpenSimplexNoise.new()
    noise.seed = randi()
    noise.octaves = 9
    #noise.persistence = rand_range(0.25, 0.75)
    noise.persistence = .5

    noise2 = OpenSimplexNoise.new()
    noise2.seed = randi()
    noise2.octaves = 9
    #noise2.persistence = rand_range(0.25, 0.75)
    noise2.persistence = 0.5

    DebugConsole.fix_message("Base Noise Seed", noise.seed)
    DebugConsole.fix_message("Base Noise Octaves", noise.octaves)
    DebugConsole.fix_message("Base Noise Persistence", noise.persistence)
    DebugConsole.fix_message("Added Noise Seed", noise2.seed)
    DebugConsole.fix_message("Added Noise Octaves", noise2.octaves)
    DebugConsole.fix_message("Added Noise Persistence", noise2.persistence)

    var texture_size = map_size
    var t = ImageTexture.new()
    t.create_from_image(noise.get_image(texture_size, texture_size))
    $Control/Sprite.texture = t
    $Control/Sprite.scale = Vector2(1024 / texture_size * .125, 1024 / texture_size * .125)

    _build_array_mesh()


func _build_array_mesh() -> void:
    var array_mesh: ArrayMesh = ArrayMesh.new()

    var verts = PoolVector3Array()

    var normals_dict = {}
    var normals_avgs = {}
    var current_point = Vector3(0, 0, 0);

    var heights = []

    max_distance = Vector2.ZERO.distance_squared_to(center)

    for x in range(-map_extra, map_size + map_extra):
        for z in range(-map_extra, map_size + map_extra):
            var pos_x = x * square_size
            var pos_z = z * square_size

            var noise_value = _get_noise_value(x, z)

            if not noise_value in heights:
                heights.append(noise_value)

            if noise_value == 0:
                continue

            var center_point = Vector3(pos_x + (square_size / 2), noise_value, pos_z + (square_size / 2))

            var avgs = []
            for set in [Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1)]:
                var upd_x = set.y
                var upd_z = set.x

                var avg_noise = (
                    noise_value + _get_noise_value(x, z + upd_z) + _get_noise_value(x + upd_x, z + upd_z) + _get_noise_value(x + upd_x, z)
                ) / 4
                avgs.append(avg_noise)

            var top_right = Vector3(pos_x + square_size, avgs[0], pos_z)
            var bottom_right = Vector3(pos_x + square_size, avgs[1], pos_z + square_size)
            var bottom_left = Vector3(pos_x, avgs[2], pos_z + square_size)
            var top_left = Vector3(pos_x, avgs[3], pos_z)

            var triangles = [
                center_point, top_right, bottom_right,
                center_point, bottom_right, bottom_left,
                center_point, bottom_left, top_left,
                center_point, top_left, top_right,
            ]

            verts.append_array(triangles)
            for t in range(4):
                var tnormal = _get_triangle_normal(triangles[(3 * t) + 2], triangles[(3 * t) + 1], triangles[(3 * t)])
                normals_dict[triangles[(3 * t)]] = normals_dict.get(triangles[(3 * t)], []) + [tnormal]
                normals_dict[triangles[(3 * t) + 1]] = normals_dict.get(triangles[(3 * t) + 1], []) + [tnormal]
                normals_dict[triangles[(3 * t) + 2]] = normals_dict.get(triangles[(3 * t) + 2], []) + [tnormal]

    for vector_point in normals_dict:
        var normal_avg = Vector3.ZERO
        for tnormal in normals_dict[vector_point]:
            normal_avg += tnormal
        normal_avg = normal_avg / len(normals_dict[vector_point])
        normals_avgs[vector_point] = normal_avg

    var normals = PoolVector3Array()
    for vector_point in verts:
        normals.append(normals_avgs[vector_point])

    var array = []
    array.resize(Mesh.ARRAY_MAX)
    array[Mesh.ARRAY_VERTEX] = verts
    array[Mesh.ARRAY_NORMAL] = normals

    array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, array)

    array_mesh.surface_set_material(0, material)

    mesh_instance.mesh = array_mesh

    mesh_shape.shape = array_mesh.create_trimesh_shape()

    #ResourceSaver.save("res://saved_mesh.tres", array_mesh)

    player.translation = Vector3(map_size * square_size / 2, 100, map_size * square_size / 2)


func _get_noise_value(x: float, z: float) -> float:
    if x < 0 or x >= map_size or z < 0 or z >= map_size:
        return map_bottom

    var noise_value = (noise.get_noise_2d(x, z) / 2.0) + .5
    var distance = (Vector2(x, z).distance_squared_to(center) / max_distance)
    noise_value = max(noise_value - distance, 0)

    var noise_mod = (noise2.get_noise_2d(x, z) / 2.0) + .5
    var height_diff = max_height - min_height
    noise_value = noise_value * (min_height + (height_diff * noise_mod))

    return noise_value if noise_value != 0.0 else map_bottom


func _get_triangle_normal(a, b, c):
    # find the surface normal given 3 vertices (counter clock wise)
    var side1 = b - a
    var side2 = c - a
    var normal = side1.cross(side2)
    return normal.normalized()
